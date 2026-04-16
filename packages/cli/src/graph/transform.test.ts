import { describe, expect, it } from 'vitest'
import { transformGraph } from './transform'
import type { ICruiseResult } from './types'

function makeCruiseResult(
  modules: {
    source: string
    deps: { resolved: string; circular?: boolean; types?: string[]; dynamic?: boolean }[]
  }[],
): ICruiseResult {
  return {
    modules: modules.map(m => ({
      source: m.source,
      valid: true,
      dependents: [],
      dependencies: m.deps.map(d => ({
        resolved: d.resolved,
        circular: d.circular ?? false,
        dependencyTypes: (d.types ?? ['local']) as never[],
        module: d.resolved,
        coreModule: false,
        couldNotResolve: false,
        dynamic: d.dynamic ?? false,
        exoticallyRequired: false,
        followable: true,
        protocol: '' as never,
        mimeType: '',
        moduleSystem: 'es6' as const,
        valid: true,
        instability: 0,
      })),
    })),
    summary: {
      error: 0,
      ignore: 0,
      info: 0,
      warn: 0,
      totalCruised: modules.length,
      violations: [],
      optionsUsed: {} as never,
    },
  }
}

describe('transformGraph', () => {
  it('builds forward and reverse maps for a simple chain A→B→C', () => {
    const cruise = makeCruiseResult([
      { source: 'a.ts', deps: [{ resolved: 'b.ts' }] },
      { source: 'b.ts', deps: [{ resolved: 'c.ts' }] },
      { source: 'c.ts', deps: [] },
    ])

    const result = transformGraph(cruise)

    expect(result.adjacencyMaps.forward.get('a.ts')).toEqual(['b.ts'])
    expect(result.adjacencyMaps.forward.get('b.ts')).toEqual(['c.ts'])
    expect(result.adjacencyMaps.forward.get('c.ts')).toEqual([])

    expect(result.adjacencyMaps.reverse.get('b.ts')).toEqual(['a.ts'])
    expect(result.adjacencyMaps.reverse.get('c.ts')).toEqual(['b.ts'])
    expect(result.adjacencyMaps.reverse.get('a.ts')).toEqual([])
  })

  it('handles fan-out: A depends on B and C', () => {
    const cruise = makeCruiseResult([
      { source: 'a.ts', deps: [{ resolved: 'b.ts' }, { resolved: 'c.ts' }] },
      { source: 'b.ts', deps: [] },
      { source: 'c.ts', deps: [] },
    ])

    const result = transformGraph(cruise)

    expect(result.adjacencyMaps.forward.get('a.ts')).toEqual(['b.ts', 'c.ts'])
    expect(result.adjacencyMaps.reverse.get('b.ts')).toEqual(['a.ts'])
    expect(result.adjacencyMaps.reverse.get('c.ts')).toEqual(['a.ts'])
  })

  it('marks circular dependencies in metadata', () => {
    const cruise = makeCruiseResult([
      { source: 'a.ts', deps: [{ resolved: 'b.ts' }] },
      { source: 'b.ts', deps: [{ resolved: 'a.ts', circular: true }] },
    ])

    const result = transformGraph(cruise)

    expect(result.metadata.get('a.ts')?.circular).toBe(true)
    expect(result.metadata.get('b.ts')?.circular).toBe(true)
  })

  it('excludes node_modules dependencies from adjacency maps', () => {
    const cruise = makeCruiseResult([
      {
        source: 'a.ts',
        deps: [{ resolved: 'b.ts' }, { resolved: 'node_modules/lodash/index.js', types: ['npm'] }],
      },
      { source: 'b.ts', deps: [] },
    ])

    const result = transformGraph(cruise)

    expect(result.adjacencyMaps.forward.get('a.ts')).toEqual(['b.ts'])
    expect(result.adjacencyMaps.forward.has('node_modules/lodash/index.js')).toBe(false)
  })

  it('deduplicates edges when multiple dependency types exist for the same target', () => {
    const cruise = makeCruiseResult([
      {
        source: 'index.ts',
        deps: [
          { resolved: 'button.ts', types: ['local'] },
          { resolved: 'button.ts', types: ['local'] },
        ],
      },
      { source: 'button.ts', deps: [] },
    ])

    const result = transformGraph(cruise)

    expect(result.adjacencyMaps.forward.get('index.ts')).toEqual(['button.ts'])
    expect(result.adjacencyMaps.reverse.get('button.ts')).toEqual(['index.ts'])
  })

  it('detects barrel files (index.ts with export dependencies)', () => {
    const cruise = makeCruiseResult([
      {
        source: 'src/components/index.ts',
        deps: [
          { resolved: 'src/components/Button.ts', types: ['local', 'export'] },
          { resolved: 'src/components/Input.ts', types: ['local', 'export'] },
        ],
      },
      { source: 'src/components/Button.ts', deps: [] },
      { source: 'src/components/Input.ts', deps: [] },
    ])

    const result = transformGraph(cruise)

    expect(result.metadata.get('src/components/index.ts')?.barrel).toBe(true)
  })

  it('does not flag non-index files as barrels even with re-exports', () => {
    const cruise = makeCruiseResult([
      {
        source: 'src/utils.ts',
        deps: [{ resolved: 'src/helpers.ts', types: ['local', 'export'] }],
      },
      { source: 'src/helpers.ts', deps: [] },
    ])

    const result = transformGraph(cruise)

    expect(result.metadata.get('src/utils.ts')?.barrel).toBe(false)
  })

  it('tracks dynamic imports in dependency metadata', () => {
    const cruise = makeCruiseResult([
      {
        source: 'app.ts',
        deps: [{ resolved: 'lazy.ts', dynamic: true }],
      },
      { source: 'lazy.ts', deps: [] },
    ])

    const result = transformGraph(cruise)

    expect(result.dependencyMetadata.get('app.ts')?.get('lazy.ts')?.dynamic).toBe(true)
  })

  it('marks non-dynamic imports as dynamic: false', () => {
    const cruise = makeCruiseResult([
      {
        source: 'app.ts',
        deps: [{ resolved: 'utils.ts' }],
      },
      { source: 'utils.ts', deps: [] },
    ])

    const result = transformGraph(cruise)

    expect(result.dependencyMetadata.get('app.ts')?.get('utils.ts')?.dynamic).toBe(false)
  })
})

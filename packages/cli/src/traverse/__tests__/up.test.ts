import { describe, expect, it } from 'vitest'
import { traverseUp } from '../up'

describe('traverseUp', () => {
  it('produces a linear tree for a single importer chain C←B←A', () => {
    const reverse = new Map([
      ['c.ts', ['b.ts']],
      ['b.ts', ['a.ts']],
      ['a.ts', []],
    ])

    const tree = traverseUp('c.ts', reverse)

    expect(tree).toEqual({
      path: 'c.ts',
      circular: false,
      markers: [],
      children: [
        {
          path: 'b.ts',
          circular: false,
          markers: [],
          children: [{ path: 'a.ts', circular: false, markers: [], children: [] }],
        },
      ],
    })
  })

  it('produces branching tree when multiple modules import the target', () => {
    const reverse = new Map([
      ['c.ts', ['a.ts', 'b.ts']],
      ['a.ts', []],
      ['b.ts', []],
    ])

    const tree = traverseUp('c.ts', reverse)

    expect(tree.children).toHaveLength(2)
    expect(tree.children[0].path).toBe('a.ts')
    expect(tree.children[1].path).toBe('b.ts')
  })

  it('marks circular references and truncates the branch', () => {
    const reverse = new Map([
      ['a.ts', ['b.ts']],
      ['b.ts', ['a.ts']],
    ])

    const tree = traverseUp('a.ts', reverse)

    expect(tree.children[0].path).toBe('b.ts')
    const circularNode = tree.children[0].children[0]
    expect(circularNode.path).toBe('a.ts')
    expect(circularNode.circular).toBe(true)
    expect(circularNode.children).toEqual([])
  })

  it('produces a leaf node when no modules import the target', () => {
    const reverse = new Map([['a.ts', []]])

    const tree = traverseUp('a.ts', reverse)

    expect(tree).toEqual({ path: 'a.ts', circular: false, markers: [], children: [] })
  })

  it('limits traversal depth when depth option is set', () => {
    const reverse = new Map([
      ['c.ts', ['b.ts']],
      ['b.ts', ['a.ts']],
      ['a.ts', []],
    ])

    const tree = traverseUp('c.ts', reverse, { depth: 1 })

    expect(tree.path).toBe('c.ts')
    expect(tree.children).toHaveLength(1)
    expect(tree.children[0].path).toBe('b.ts')
    expect(tree.children[0].children).toEqual([])
  })

  it('excludes modules matching the exclude pattern', () => {
    const reverse = new Map([
      ['c.ts', ['a.ts', 'b.test.ts']],
      ['a.ts', []],
      ['b.test.ts', []],
    ])

    const tree = traverseUp('c.ts', reverse, { exclude: /\.test\.ts$/ })

    expect(tree.children).toHaveLength(1)
    expect(tree.children[0].path).toBe('a.ts')
  })

  it('filters direct importers with importsSymbol callback', () => {
    const reverse = new Map([
      ['target.ts', ['uses-symbol.ts', 'no-symbol.ts']],
      ['uses-symbol.ts', ['grandparent.ts']],
      ['no-symbol.ts', []],
      ['grandparent.ts', []],
    ])

    const tree = traverseUp('target.ts', reverse, {
      importsSymbol: imp => imp === 'uses-symbol.ts',
    })

    expect(tree.children).toHaveLength(1)
    expect(tree.children[0].path).toBe('uses-symbol.ts')
    // Grandparent should still be traversed normally (no filter at depth > 1)
    expect(tree.children[0].children).toHaveLength(1)
    expect(tree.children[0].children[0].path).toBe('grandparent.ts')
  })

  it('does not apply importsSymbol at deeper levels', () => {
    const reverse = new Map([
      ['target.ts', ['a.ts']],
      ['a.ts', ['b.ts', 'c.ts']],
      ['b.ts', []],
      ['c.ts', []],
    ])

    // Filter only passes 'a.ts' at depth 1, but b.ts and c.ts at depth 2 are unfiltered
    const tree = traverseUp('target.ts', reverse, {
      importsSymbol: imp => imp === 'a.ts',
    })

    expect(tree.children).toHaveLength(1)
    expect(tree.children[0].path).toBe('a.ts')
    expect(tree.children[0].children).toHaveLength(2)
  })
  it('annotates importers with references and propagates exposed names one hop up', () => {
    const reverse = new Map([
      ['target.ts', ['barrel.ts']],
      ['barrel.ts', ['app.ts']],
      ['app.ts', []],
    ])
    const calls: [string, string, string[]][] = []

    const tree = traverseUp('target.ts', reverse, {
      symbolTracking: {
        names: ['Foo'],
        analyze: (importer, imported, names) => {
          calls.push([importer, imported, names])
          return importer === 'barrel.ts'
            ? {
                reference: { line: 1, column: 10, kind: 'import' },
                exposedAs: ['Bar'],
              }
            : { reference: { line: 4, column: 2, kind: 'usage' }, exposedAs: [] }
        },
      },
    })

    expect(calls).toEqual([
      ['barrel.ts', 'target.ts', ['Foo']],
      ['app.ts', 'barrel.ts', ['Bar']],
    ])
    expect(tree.reference).toBeUndefined()
    expect(tree.children[0].reference).toEqual({ line: 1, column: 10, kind: 'import' })
    expect(tree.children[0].children[0].reference).toEqual({ line: 4, column: 2, kind: 'usage' })
  })

  it('omits references when symbol tracking is not enabled', () => {
    const reverse = new Map([
      ['target.ts', ['a.ts']],
      ['a.ts', []],
    ])

    const tree = traverseUp('target.ts', reverse)

    expect(tree.children[0]).not.toHaveProperty('reference')
  })
})

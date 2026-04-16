import type { DependencyType } from 'dependency-cruiser'
import type { GraphData, ICruiseResult } from './types'

const NPM_DEP_TYPES: Set<string> = new Set<DependencyType>([
  'npm',
  'npm-dev',
  'npm-optional',
  'npm-peer',
  'npm-no-pkg',
  'npm-bundled',
  'npm-unknown',
  'core',
])

function isNpmDependency(depTypes: DependencyType[]): boolean {
  return depTypes.some(t => NPM_DEP_TYPES.has(t))
}

export function transformGraph(cruiseResult: ICruiseResult): GraphData {
  const forward = new Map<string, string[]>()
  const reverse = new Map<string, string[]>()
  const metadata = new Map<string, { circular: boolean }>()

  for (const mod of cruiseResult.modules) {
    const source = mod.source
    if (source.includes('node_modules')) continue

    if (!forward.has(source)) forward.set(source, [])
    if (!reverse.has(source)) reverse.set(source, [])

    for (const dep of mod.dependencies) {
      if (isNpmDependency(dep.dependencyTypes)) continue

      const target = dep.resolved
      forward.get(source)!.push(target)

      if (!reverse.has(target)) reverse.set(target, [])
      reverse.get(target)!.push(source)

      if (!forward.has(target)) forward.set(target, [])

      if (dep.circular) {
        metadata.set(source, { circular: true })
        metadata.set(target, { circular: true })
      }
    }
  }

  return { adjacencyMaps: { forward, reverse }, metadata }
}

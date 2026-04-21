import type { DependencyType } from 'dependency-cruiser'
import type { DependencyFlags, DependencyMetadata, GraphData, ICruiseResult } from './types'

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

const INDEX_FILE_PATTERN = /(?:^|\/|\\)index\.[tj]sx?$/

function isNpmDependency(depTypes: DependencyType[]): boolean {
  return depTypes.some(t => NPM_DEP_TYPES.has(t))
}

function isExportDep(depTypes: DependencyType[]): boolean {
  return depTypes.includes('export')
}

/**
 * Converts raw dependency-cruiser output into the app's internal graph representation:
 * forward and reverse adjacency maps, per-module metadata (circular references, barrel
 * detection), and per-edge flags (e.g. dynamic imports). npm and core dependencies are
 * filtered out.
 */
export function transformGraph(cruiseResult: ICruiseResult): GraphData {
  const forward = new Map<string, string[]>()
  const reverse = new Map<string, string[]>()
  const metadata = new Map<string, { circular: boolean; barrel: boolean }>()
  const dependencyMetadata: DependencyMetadata = new Map()

  for (const mod of cruiseResult.modules) {
    const source = mod.source
    if (source.includes('node_modules')) continue

    if (!forward.has(source)) forward.set(source, [])
    if (!reverse.has(source)) reverse.set(source, [])
    if (!dependencyMetadata.has(source)) dependencyMetadata.set(source, new Map())

    const seenTargets = new Set<string>()
    let hasExportDeps = false
    let hasNonExportLocalDeps = false

    for (const dep of mod.dependencies) {
      if (isNpmDependency(dep.dependencyTypes)) continue

      const target = dep.resolved

      // Track dependency flags (dynamic) even for duplicates
      const depFlags: DependencyFlags = { dynamic: dep.dynamic }
      dependencyMetadata.get(source)!.set(target, depFlags)

      if (seenTargets.has(target)) continue
      seenTargets.add(target)

      forward.get(source)!.push(target)

      if (!reverse.has(target)) reverse.set(target, [])
      reverse.get(target)!.push(source)

      if (!forward.has(target)) forward.set(target, [])

      if (dep.circular) {
        ensureMetadata(metadata, source).circular = true
        ensureMetadata(metadata, target).circular = true
      }

      if (isExportDep(dep.dependencyTypes)) {
        hasExportDeps = true
      } else {
        hasNonExportLocalDeps = true
      }
    }

    // Barrel detection: index file where all local deps are re-exports
    const isBarrel = INDEX_FILE_PATTERN.test(source) && hasExportDeps && !hasNonExportLocalDeps
    ensureMetadata(metadata, source).barrel = isBarrel
  }

  return { adjacencyMaps: { forward, reverse }, metadata, dependencyMetadata }
}

function ensureMetadata(
  metadata: Map<string, { circular: boolean; barrel: boolean }>,
  key: string,
): { circular: boolean; barrel: boolean } {
  let entry = metadata.get(key)
  if (!entry) {
    entry = { circular: false, barrel: false }
    metadata.set(key, entry)
  }
  return entry
}

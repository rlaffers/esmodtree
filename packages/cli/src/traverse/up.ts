import type { DependencyMetadata, ModuleMarker, TreeNode } from '~/graph/types'

export type TraverseOptions = {
  markers?: Map<string, ModuleMarker[]>
  dependencyMetadata?: DependencyMetadata
  depth?: number
  exclude?: RegExp
}

export function traverseUp(
  startFile: string,
  reverse: Map<string, string[]>,
  options: TraverseOptions = {},
): TreeNode {
  const { markers = new Map(), dependencyMetadata = new Map(), depth: maxDepth, exclude } = options
  const visited = new Set<string>()

  function walk(file: string, edgeMarkers: ModuleMarker[], currentDepth: number): TreeNode {
    if (visited.has(file)) {
      return { path: file, circular: true, markers: edgeMarkers, children: [] }
    }

    if (maxDepth !== undefined && currentDepth >= maxDepth) {
      const nodeMarkers = [...edgeMarkers, ...(markers.get(file) ?? [])]
      return { path: file, circular: false, markers: nodeMarkers, children: [] }
    }

    visited.add(file)
    const importers = (reverse.get(file) ?? []).filter(imp => !exclude || !exclude.test(imp))
    const children = importers.map(imp => {
      const depEdgeMarkers: ModuleMarker[] = []
      // In --up mode, the edge goes from importer → file
      // so check if importer dynamically imports this file
      if (dependencyMetadata.get(imp)?.get(file)?.dynamic) {
        depEdgeMarkers.push('dynamic')
      }
      return walk(imp, depEdgeMarkers, currentDepth + 1)
    })
    visited.delete(file)

    const nodeMarkers = [...edgeMarkers, ...(markers.get(file) ?? [])]
    return { path: file, circular: false, markers: nodeMarkers, children }
  }

  return walk(startFile, [], 0)
}

import type { DependencyMetadata, ModuleMarker, TreeNode } from '~/graph/types'

export type TraverseOptions = {
  markers?: Map<string, ModuleMarker[]>
  dependencyMetadata?: DependencyMetadata
}

export function traverseUp(
  startFile: string,
  reverse: Map<string, string[]>,
  options: TraverseOptions = {},
): TreeNode {
  const { markers = new Map(), dependencyMetadata = new Map() } = options
  const visited = new Set<string>()

  function walk(file: string, edgeMarkers: ModuleMarker[]): TreeNode {
    if (visited.has(file)) {
      return { path: file, circular: true, markers: edgeMarkers, children: [] }
    }

    visited.add(file)
    const importers = reverse.get(file) ?? []
    const children = importers.map(imp => {
      const depEdgeMarkers: ModuleMarker[] = []
      // In --up mode, the edge goes from importer → file
      // so check if importer dynamically imports this file
      if (dependencyMetadata.get(imp)?.get(file)?.dynamic) {
        depEdgeMarkers.push('dynamic')
      }
      return walk(imp, depEdgeMarkers)
    })
    visited.delete(file)

    const nodeMarkers = [...edgeMarkers, ...(markers.get(file) ?? [])]
    return { path: file, circular: false, markers: nodeMarkers, children }
  }

  return walk(startFile, [])
}

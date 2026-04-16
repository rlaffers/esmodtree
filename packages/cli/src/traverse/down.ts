import type { DependencyMetadata, ModuleMarker, TreeNode } from '~/graph/types'

export type TraverseOptions = {
  markers?: Map<string, ModuleMarker[]>
  dependencyMetadata?: DependencyMetadata
}

export function traverseDown(
  startFile: string,
  forward: Map<string, string[]>,
  options: TraverseOptions = {},
): TreeNode {
  const { markers = new Map(), dependencyMetadata = new Map() } = options
  const visited = new Set<string>()

  function walk(file: string, edgeMarkers: ModuleMarker[]): TreeNode {
    if (visited.has(file)) {
      return { path: file, circular: true, markers: edgeMarkers, children: [] }
    }

    visited.add(file)
    const deps = forward.get(file) ?? []
    const children = deps.map(dep => {
      const depEdgeMarkers: ModuleMarker[] = []
      if (dependencyMetadata.get(file)?.get(dep)?.dynamic) {
        depEdgeMarkers.push('dynamic')
      }
      return walk(dep, depEdgeMarkers)
    })
    visited.delete(file)

    const nodeMarkers = [...edgeMarkers, ...(markers.get(file) ?? [])]
    return { path: file, circular: false, markers: nodeMarkers, children }
  }

  return walk(startFile, [])
}

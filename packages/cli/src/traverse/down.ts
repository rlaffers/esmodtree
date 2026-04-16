import type { DependencyMetadata, ModuleMarker, TreeNode } from '~/graph/types'

export type TraverseOptions = {
  markers?: Map<string, ModuleMarker[]>
  dependencyMetadata?: DependencyMetadata
  depth?: number
  exclude?: RegExp
}

export function traverseDown(
  startFile: string,
  forward: Map<string, string[]>,
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
    const deps = (forward.get(file) ?? []).filter(dep => !exclude || !exclude.test(dep))
    const children = deps.map(dep => {
      const depEdgeMarkers: ModuleMarker[] = []
      if (dependencyMetadata.get(file)?.get(dep)?.dynamic) {
        depEdgeMarkers.push('dynamic')
      }
      return walk(dep, depEdgeMarkers, currentDepth + 1)
    })
    visited.delete(file)

    const nodeMarkers = [...edgeMarkers, ...(markers.get(file) ?? [])]
    return { path: file, circular: false, markers: nodeMarkers, children }
  }

  return walk(startFile, [], 0)
}

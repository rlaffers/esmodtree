import type { ModuleMarker, TreeNode } from '~/graph/types'

export type TraverseOptions = {
  markers?: Map<string, ModuleMarker[]>
}

export function traverseUp(
  startFile: string,
  reverse: Map<string, string[]>,
  options: TraverseOptions = {},
): TreeNode {
  const { markers = new Map() } = options
  const visited = new Set<string>()

  function walk(file: string): TreeNode {
    if (visited.has(file)) {
      return { path: file, circular: true, markers: [], children: [] }
    }

    visited.add(file)
    const importers = reverse.get(file) ?? []
    const children = importers.map(imp => walk(imp))
    visited.delete(file)

    return { path: file, circular: false, markers: markers.get(file) ?? [], children }
  }

  return walk(startFile)
}

import type { TreeNode } from '~/graph/types'

export function traverseUp(startFile: string, reverse: Map<string, string[]>): TreeNode {
  const visited = new Set<string>()

  function walk(file: string): TreeNode {
    if (visited.has(file)) {
      return { path: file, circular: true, children: [] }
    }

    visited.add(file)
    const importers = reverse.get(file) ?? []
    const children = importers.map(imp => walk(imp))
    visited.delete(file)

    return { path: file, circular: false, children }
  }

  return walk(startFile)
}

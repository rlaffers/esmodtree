import type { TreeNode } from '~/graph/types'

export function traverseDown(startFile: string, forward: Map<string, string[]>): TreeNode {
  const visited = new Set<string>()

  function walk(file: string): TreeNode {
    if (visited.has(file)) {
      return { path: file, circular: true, children: [] }
    }

    visited.add(file)
    const deps = forward.get(file) ?? []
    const children = deps.map(dep => walk(dep))
    visited.delete(file)

    return { path: file, circular: false, children }
  }

  return walk(startFile)
}

import type { TreeNode } from '~/graph/types'

export function formatJson(node: TreeNode): string {
  return JSON.stringify(node, null, 2)
}

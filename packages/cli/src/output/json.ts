import type { TreeNode } from '~/graph/types'

export function formatJson(nodeOrForest: TreeNode | TreeNode[]): string {
  return JSON.stringify(nodeOrForest, null, 2)
}

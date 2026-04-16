import type { TreeNode } from '~/graph/types'

export function formatTree(node: TreeNode): string {
  const lines: string[] = []

  function walk(n: TreeNode, prefix: string, isLast: boolean, isRoot: boolean) {
    const connector = isRoot ? '' : isLast ? '└── ' : '├── '
    const label = n.circular ? `${n.path} [circular]` : n.path
    lines.push(`${prefix}${connector}${label}`)

    const childPrefix = isRoot ? '' : prefix + (isLast ? '    ' : '│   ')
    n.children.forEach((child, i) => {
      walk(child, childPrefix, i === n.children.length - 1, false)
    })
  }

  walk(node, '', true, true)
  return lines.join('\n')
}

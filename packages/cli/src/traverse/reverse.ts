import type { TreeNode } from '~/graph/types'

/**
 * Reverses an "up" tree so that top-level ancestors become roots
 * and the original root (queried file) appears at the bottom of each branch.
 *
 * Returns a forest (array of trees) because the reversed tree may have
 * multiple roots when the original tree has multiple leaf ancestors.
 */
export function reverseTree(root: TreeNode): TreeNode[] {
  const paths: TreeNode[][] = []

  function collectPaths(node: TreeNode, currentPath: TreeNode[]) {
    currentPath.push(node)
    if (node.children.length === 0) {
      paths.push([...currentPath])
    } else {
      for (const child of node.children) {
        collectPaths(child, currentPath)
      }
    }
    currentPath.pop()
  }

  collectPaths(root, [])

  // Reverse each path so ancestors come first, queried file last
  const reversedPaths = paths.map(p => [...p].reverse())

  // Build a forest by merging common prefixes (trie-style)
  const forest: TreeNode[] = []
  for (const path of reversedPaths) {
    insertPath(forest, path)
  }

  return forest
}

function insertPath(siblings: TreeNode[], path: TreeNode[]) {
  if (path.length === 0) return

  const [head, ...tail] = path
  const existing = siblings.find(s => s.path === head.path)

  if (existing) {
    // Merge into existing node — continue down the tail
    insertPath(existing.children, tail)
  } else {
    // Create a new branch from here
    const node = buildChain(path)
    siblings.push(node)
  }
}

/** Builds a linear chain of TreeNodes from a path segment. */
function buildChain(path: TreeNode[]): TreeNode {
  if (path.length === 1) {
    return cloneLeaf(path[0])
  }

  const [head, ...tail] = path
  return {
    path: head.path,
    circular: head.circular,
    markers: [...head.markers],
    children: [buildChain(tail)],
  }
}

function cloneLeaf(node: TreeNode): TreeNode {
  return {
    path: node.path,
    circular: node.circular,
    markers: [...node.markers],
    children: [],
  }
}

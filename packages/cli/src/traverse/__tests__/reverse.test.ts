import { describe, expect, it } from 'vitest'
import type { TreeNode } from '~/graph/types'
import { reverseTree } from '../reverse'

function node(
  path: string,
  children: TreeNode[] = [],
  markers: TreeNode['markers'] = [],
): TreeNode {
  return { path, circular: false, markers, children }
}

describe('reverseTree', () => {
  it('reverses a linear chain C→B→A into A→B→C', () => {
    const tree = node('c.ts', [node('b.ts', [node('a.ts')])])

    const forest = reverseTree(tree)

    expect(forest).toEqual([node('a.ts', [node('b.ts', [node('c.ts')])])])
  })

  it('returns a forest when the up-tree branches', () => {
    // --up tree: Button.ts has two importers
    const tree = node('button.ts', [
      node('index.ts', [node('app.ts', [node('entry.ts', [], ['entry'])])], ['barrel']),
      node('consumer.ts'),
    ])

    const forest = reverseTree(tree)

    expect(forest).toEqual([
      node(
        'entry.ts',
        [node('app.ts', [node('index.ts', [node('button.ts')], ['barrel'])])],
        ['entry'],
      ),
      node('consumer.ts', [node('button.ts')]),
    ])
  })

  it('merges common prefixes across paths', () => {
    // A has children B and C; B has child D; C has child D
    // Paths: A→B→D, A→C→D
    // Reversed: D→B→A, D→C→A  → merge prefix D
    const tree = node('a.ts', [node('b.ts', [node('d.ts')]), node('c.ts', [node('d.ts')])])

    const forest = reverseTree(tree)

    expect(forest).toHaveLength(1)
    expect(forest[0].path).toBe('d.ts')
    expect(forest[0].children).toHaveLength(2)
    expect(forest[0].children[0].path).toBe('b.ts')
    expect(forest[0].children[1].path).toBe('c.ts')
    // Both branches end at a.ts
    expect(forest[0].children[0].children[0].path).toBe('a.ts')
    expect(forest[0].children[1].children[0].path).toBe('a.ts')
  })

  it('returns a single leaf when the tree has no children', () => {
    const tree = node('a.ts')

    const forest = reverseTree(tree)

    expect(forest).toEqual([node('a.ts')])
  })

  it('preserves markers on reversed nodes', () => {
    const tree = node('button.ts', [node('barrel.ts', [], ['barrel'])])

    const forest = reverseTree(tree)

    expect(forest).toEqual([node('barrel.ts', [node('button.ts')], ['barrel'])])
  })

  it('preserves circular flag on reversed nodes', () => {
    const circularNode: TreeNode = {
      path: 'a.ts',
      circular: true,
      markers: [],
      children: [],
    }
    const tree = node('b.ts', [node('c.ts', [circularNode])])

    const forest = reverseTree(tree)

    // Reversed path: a.ts(circular) → c.ts → b.ts
    expect(forest[0].circular).toBe(true)
    expect(forest[0].path).toBe('a.ts')
    expect(forest[0].children[0].path).toBe('c.ts')
    expect(forest[0].children[0].children[0].path).toBe('b.ts')
  })
})

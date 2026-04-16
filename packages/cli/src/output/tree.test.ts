import { describe, expect, it } from 'vitest'
import { formatTree } from './tree'
import type { TreeNode } from '~/graph/types'

describe('formatTree', () => {
  it('renders a single node with no children', () => {
    const node: TreeNode = { path: 'a.ts', circular: false, children: [] }

    expect(formatTree(node)).toBe('a.ts')
  })

  it('renders a deep chain with proper connectors', () => {
    const node: TreeNode = {
      path: 'a.ts',
      circular: false,
      children: [
        {
          path: 'b.ts',
          circular: false,
          children: [{ path: 'c.ts', circular: false, children: [] }],
        },
      ],
    }

    expect(formatTree(node)).toBe(['a.ts', '└── b.ts', '    └── c.ts'].join('\n'))
  })

  it('renders wide branching with ├── and └── connectors', () => {
    const node: TreeNode = {
      path: 'a.ts',
      circular: false,
      children: [
        { path: 'b.ts', circular: false, children: [] },
        { path: 'c.ts', circular: false, children: [] },
        { path: 'd.ts', circular: false, children: [] },
      ],
    }

    expect(formatTree(node)).toBe(['a.ts', '├── b.ts', '├── c.ts', '└── d.ts'].join('\n'))
  })

  it('renders [circular] marker for circular nodes', () => {
    const node: TreeNode = {
      path: 'a.ts',
      circular: false,
      children: [
        {
          path: 'b.ts',
          circular: false,
          children: [{ path: 'a.ts', circular: true, children: [] }],
        },
      ],
    }

    expect(formatTree(node)).toBe(['a.ts', '└── b.ts', '    └── a.ts [circular]'].join('\n'))
  })
})

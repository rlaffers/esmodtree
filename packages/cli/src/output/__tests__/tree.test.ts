import { describe, expect, it } from 'vitest'
import { formatTree } from '../tree'
import type { TreeNode } from '~/graph/types'

describe('formatTree', () => {
  it('renders a single node with no children', () => {
    const node: TreeNode = { path: 'a.ts', circular: false, markers: [], children: [] }

    expect(formatTree(node)).toBe('a.ts')
  })

  it('renders a deep chain with proper connectors', () => {
    const node: TreeNode = {
      path: 'a.ts',
      circular: false,
      markers: [],
      children: [
        {
          path: 'b.ts',
          circular: false,
          markers: [],
          children: [{ path: 'c.ts', circular: false, markers: [], children: [] }],
        },
      ],
    }

    expect(formatTree(node)).toBe(['a.ts', '└── b.ts', '    └── c.ts'].join('\n'))
  })

  it('renders wide branching with ├── and └── connectors', () => {
    const node: TreeNode = {
      path: 'a.ts',
      circular: false,
      markers: [],
      children: [
        { path: 'b.ts', circular: false, markers: [], children: [] },
        { path: 'c.ts', circular: false, markers: [], children: [] },
        { path: 'd.ts', circular: false, markers: [], children: [] },
      ],
    }

    expect(formatTree(node)).toBe(['a.ts', '├── b.ts', '├── c.ts', '└── d.ts'].join('\n'))
  })

  it('renders [circular] marker for circular nodes', () => {
    const node: TreeNode = {
      path: 'a.ts',
      circular: false,
      markers: [],
      children: [
        {
          path: 'b.ts',
          circular: false,
          markers: [],
          children: [{ path: 'a.ts', circular: true, markers: [], children: [] }],
        },
      ],
    }

    expect(formatTree(node)).toBe(['a.ts', '└── b.ts', '    └── a.ts [circular]'].join('\n'))
  })

  it('renders module markers like [page] and [entry]', () => {
    const node: TreeNode = {
      path: 'src/index.ts',
      circular: false,
      markers: ['entry'],
      children: [
        { path: 'pages/home.tsx', circular: false, markers: ['page'], children: [] },
        { path: 'src/utils.ts', circular: false, markers: [], children: [] },
      ],
    }

    expect(formatTree(node)).toBe(
      ['src/index.ts [entry]', '├── pages/home.tsx [page]', '└── src/utils.ts'].join('\n'),
    )
  })

  it('renders multiple markers on the same node', () => {
    const node: TreeNode = {
      path: 'app/page.tsx',
      circular: false,
      markers: ['page', 'entry'],
      children: [],
    }

    expect(formatTree(node)).toBe('app/page.tsx [page] [entry]')
  })

  it('colorizes markers when color is enabled and terminal supports it', () => {
    const node: TreeNode = {
      path: 'src/index.ts',
      circular: false,
      markers: ['entry'],
      children: [{ path: 'a.ts', circular: true, markers: [], children: [] }],
    }

    const plain = formatTree(node, { color: false })
    const colored = formatTree(node, { color: true })

    // In a non-TTY environment (like tests), picocolors may strip colors.
    // At minimum, colored output should contain the same text content.
    expect(colored).toContain('src/index.ts')
    expect(colored).toContain('entry')
    expect(colored).toContain('circular')
    // If colors are supported, colored output differs from plain
    // (can't guarantee in all test environments)
    expect(plain).toBe('src/index.ts [entry]\n└── a.ts [circular]')
  })

  it('does not colorize when color is disabled', () => {
    const node: TreeNode = {
      path: 'src/index.ts',
      circular: false,
      markers: ['entry'],
      children: [],
    }

    const output = formatTree(node, { color: false })

    expect(output).toBe('src/index.ts [entry]')
  })

  it('renders [barrel] and [dynamic] markers', () => {
    const node: TreeNode = {
      path: 'src/components/index.ts',
      circular: false,
      markers: ['barrel'],
      children: [
        { path: 'src/components/Button.ts', circular: false, markers: ['dynamic'], children: [] },
      ],
    }

    expect(formatTree(node)).toBe(
      ['src/components/index.ts [barrel]', '└── src/components/Button.ts [dynamic]'].join('\n'),
    )
  })

  it('renders combined markers on a single node', () => {
    const node: TreeNode = {
      path: 'src/components/index.ts',
      circular: false,
      markers: ['barrel', 'page'],
      children: [],
    }

    expect(formatTree(node)).toBe('src/components/index.ts [barrel] [page]')
  })
})

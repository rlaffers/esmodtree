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
      path: 'app/page.tsx',
      circular: false,
      markers: ['page', 'entry'],
      children: [],
    }

    expect(formatTree(node)).toBe('app/page.tsx [page] [entry]')
  })

  it('renders a forest (array of trees) with each root separated by a blank line', () => {
    const forest: TreeNode[] = [
      {
        path: 'src/index.ts',
        circular: false,
        markers: ['entry'],
        children: [
          {
            path: 'src/app.ts',
            circular: false,
            markers: [],
            children: [{ path: 'src/button.ts', circular: false, markers: [], children: [] }],
          },
        ],
      },
      {
        path: 'src/consumer.ts',
        circular: false,
        markers: [],
        children: [{ path: 'src/button.ts', circular: false, markers: [], children: [] }],
      },
    ]

    expect(formatTree(forest)).toBe(
      [
        'src/index.ts [entry]',
        '└── src/app.ts',
        '    └── src/button.ts',
        'src/consumer.ts',
        '└── src/button.ts',
      ].join('\n'),
    )
  })

  it('renders a single-element forest the same as a single node', () => {
    const node: TreeNode = {
      path: 'a.ts',
      circular: false,
      markers: [],
      children: [{ path: 'b.ts', circular: false, markers: [], children: [] }],
    }

    expect(formatTree([node])).toBe(formatTree(node))
  })
})

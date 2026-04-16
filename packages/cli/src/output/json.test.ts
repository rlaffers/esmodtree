import { describe, expect, it } from 'vitest'
import { formatJson } from './json'
import type { TreeNode } from '~/graph/types'

describe('formatJson', () => {
  it('produces valid JSON matching the TreeNode structure', () => {
    const node: TreeNode = { path: 'a.ts', circular: false, markers: [], children: [] }

    const result = formatJson(node)
    const parsed = JSON.parse(result)

    expect(parsed).toEqual({ path: 'a.ts', circular: false, markers: [], children: [] })
  })

  it('handles nested trees with markers', () => {
    const node: TreeNode = {
      path: 'src/index.ts',
      circular: false,
      markers: ['entry'],
      children: [
        {
          path: 'src/utils.ts',
          circular: false,
          markers: ['barrel'],
          children: [{ path: 'src/helpers.ts', circular: false, markers: [], children: [] }],
        },
        { path: 'src/index.ts', circular: true, markers: [], children: [] },
      ],
    }

    const result = formatJson(node)
    const parsed = JSON.parse(result)

    expect(parsed.path).toBe('src/index.ts')
    expect(parsed.markers).toEqual(['entry'])
    expect(parsed.children).toHaveLength(2)
    expect(parsed.children[0].markers).toEqual(['barrel'])
    expect(parsed.children[0].children[0].path).toBe('src/helpers.ts')
    expect(parsed.children[1].circular).toBe(true)
  })
})

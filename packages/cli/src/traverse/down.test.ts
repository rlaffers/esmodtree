import { describe, expect, it } from 'vitest'
import { traverseDown } from './down'

describe('traverseDown', () => {
  it('produces a linear tree for a simple chain A→B→C', () => {
    const forward = new Map([
      ['a.ts', ['b.ts']],
      ['b.ts', ['c.ts']],
      ['c.ts', []],
    ])

    const tree = traverseDown('a.ts', forward)

    expect(tree).toEqual({
      path: 'a.ts',
      circular: false,
      children: [
        {
          path: 'b.ts',
          circular: false,
          children: [{ path: 'c.ts', circular: false, children: [] }],
        },
      ],
    })
  })

  it('produces branching tree for fan-out A→B, A→C', () => {
    const forward = new Map([
      ['a.ts', ['b.ts', 'c.ts']],
      ['b.ts', []],
      ['c.ts', []],
    ])

    const tree = traverseDown('a.ts', forward)

    expect(tree.children).toHaveLength(2)
    expect(tree.children[0].path).toBe('b.ts')
    expect(tree.children[1].path).toBe('c.ts')
  })

  it('marks circular references and truncates the branch', () => {
    const forward = new Map([
      ['a.ts', ['b.ts']],
      ['b.ts', ['a.ts']],
    ])

    const tree = traverseDown('a.ts', forward)

    expect(tree.children[0].path).toBe('b.ts')
    expect(tree.children[0].circular).toBe(false)
    // b.ts → a.ts should be marked circular with no further children
    const circularNode = tree.children[0].children[0]
    expect(circularNode.path).toBe('a.ts')
    expect(circularNode.circular).toBe(true)
    expect(circularNode.children).toEqual([])
  })
})

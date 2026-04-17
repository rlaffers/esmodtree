import { describe, expect, it } from 'vitest'
import { traverseDown } from '../down'

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
      markers: [],
      children: [
        {
          path: 'b.ts',
          circular: false,
          markers: [],
          children: [{ path: 'c.ts', circular: false, markers: [], children: [] }],
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

  it('returns root only when depth=0', () => {
    const forward = new Map([
      ['a.ts', ['b.ts']],
      ['b.ts', ['c.ts']],
      ['c.ts', []],
    ])

    const tree = traverseDown('a.ts', forward, { depth: 0 })

    expect(tree).toEqual({ path: 'a.ts', circular: false, markers: [], children: [] })
  })

  it('truncates after first level when depth=1', () => {
    const forward = new Map([
      ['a.ts', ['b.ts']],
      ['b.ts', ['c.ts']],
      ['c.ts', []],
    ])

    const tree = traverseDown('a.ts', forward, { depth: 1 })

    expect(tree.path).toBe('a.ts')
    expect(tree.children).toHaveLength(1)
    expect(tree.children[0].path).toBe('b.ts')
    expect(tree.children[0].children).toEqual([])
  })

  it('marks dynamically imported children with [dynamic]', () => {
    const forward = new Map([
      ['app.ts', ['lazy.ts']],
      ['lazy.ts', []],
    ])
    const dependencyMetadata = new Map([['app.ts', new Map([['lazy.ts', { dynamic: true }]])]])

    const tree = traverseDown('app.ts', forward, { dependencyMetadata })

    expect(tree.children[0].path).toBe('lazy.ts')
    expect(tree.children[0].markers).toContain('dynamic')
  })

  it('excludes modules matching the exclude pattern', () => {
    const forward = new Map([
      ['a.ts', ['b.ts', 'c.test.ts']],
      ['b.ts', []],
      ['c.test.ts', []],
    ])

    const tree = traverseDown('a.ts', forward, { exclude: /\.test\.ts$/ })

    expect(tree.children).toHaveLength(1)
    expect(tree.children[0].path).toBe('b.ts')
  })

  it('does not exclude the root even if it matches the exclude pattern', () => {
    const forward = new Map([
      ['a.test.ts', ['b.ts']],
      ['b.ts', []],
    ])

    const tree = traverseDown('a.test.ts', forward, { exclude: /\.test\.ts$/ })

    expect(tree.path).toBe('a.test.ts')
    expect(tree.children).toHaveLength(1)
    expect(tree.children[0].path).toBe('b.ts')
  })
})

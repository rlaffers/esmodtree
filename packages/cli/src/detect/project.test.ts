import { describe, expect, it } from 'vitest'
import { detectSourceDirs } from './project'

describe('detectSourceDirs', () => {
  it('returns existing common source directories', () => {
    const exists = new Set(['src', 'app', 'lib', 'node_modules', 'dist'])

    const dirs = detectSourceDirs(dir => exists.has(dir))

    expect(dirs).toEqual(['src', 'app', 'lib'])
  })

  it('returns only directories that exist', () => {
    const exists = new Set(['src'])

    const dirs = detectSourceDirs(dir => exists.has(dir))

    expect(dirs).toEqual(['src'])
  })

  it('returns empty array when no common directories found', () => {
    const dirs = detectSourceDirs(() => false)

    expect(dirs).toEqual([])
  })
})

import { describe, expect, it } from 'vitest'
import { ProjectType, detectProjectType, detectSourceDirs } from './project'

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

describe('detectProjectType', () => {
  it('detects Next.js when next.config.* exists', () => {
    const files = new Set(['next.config.js', 'package.json', 'tsconfig.json'])

    expect(detectProjectType(file => files.has(file))).toBe(ProjectType.NextJs)
  })

  it('detects Next.js with .mjs config', () => {
    const files = new Set(['next.config.mjs'])

    expect(detectProjectType(file => files.has(file))).toBe(ProjectType.NextJs)
  })

  it('detects Next.js with .ts config', () => {
    const files = new Set(['next.config.ts'])

    expect(detectProjectType(file => files.has(file))).toBe(ProjectType.NextJs)
  })

  it('returns generic when no framework config found', () => {
    const files = new Set(['package.json', 'tsconfig.json'])

    expect(detectProjectType(file => files.has(file))).toBe(ProjectType.Generic)
  })
})

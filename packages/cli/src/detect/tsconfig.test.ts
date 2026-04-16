import { describe, expect, it } from 'vitest'
import { detectTsConfig, getSourceDirsFromTsConfig } from './tsconfig'

describe('detectTsConfig', () => {
  it('finds tsconfig.json by walking up directories', () => {
    const existingFiles = new Set(['/project/tsconfig.json'])

    const result = detectTsConfig('/project/src/deep', {
      fileExists: path => existingFiles.has(path),
    })

    expect(result).toBe('/project/tsconfig.json')
  })

  it('returns undefined when no tsconfig found before project root', () => {
    // package.json exists at /project (project root), no tsconfig anywhere
    const existingFiles = new Set(['/project/package.json'])

    const result = detectTsConfig('/project/src/deep', {
      fileExists: path => existingFiles.has(path),
    })

    expect(result).toBeUndefined()
  })

  it('stops at project root (directory with package.json) even without tsconfig', () => {
    // tsconfig exists above project root, but we should not reach it
    const existingFiles = new Set(['/tsconfig.json', '/project/package.json'])

    const result = detectTsConfig('/project/src', {
      fileExists: path => existingFiles.has(path),
    })

    expect(result).toBeUndefined()
  })

  it('returns undefined when reaching filesystem root', () => {
    const result = detectTsConfig('/project/src', {
      fileExists: () => false,
    })

    expect(result).toBeUndefined()
  })
})

describe('getSourceDirsFromTsConfig', () => {
  it('extracts directories from include patterns', () => {
    const tsConfig = {
      include: ['src/**/*.ts', 'lib/**/*.tsx'],
    }

    const dirs = getSourceDirsFromTsConfig(tsConfig)

    expect(dirs).toEqual(['src', 'lib'])
  })

  it('returns empty array when tsconfig has no include field', () => {
    const dirs = getSourceDirsFromTsConfig({})

    expect(dirs).toEqual([])
  })

  it('deduplicates directories from multiple patterns with same root', () => {
    const tsConfig = {
      include: ['src/**/*.ts', 'src/**/*.tsx'],
    }

    const dirs = getSourceDirsFromTsConfig(tsConfig)

    expect(dirs).toEqual(['src'])
  })
})

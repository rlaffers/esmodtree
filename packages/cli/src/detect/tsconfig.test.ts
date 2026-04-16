import { describe, expect, it } from 'vitest'
import { detectTsConfig, getSourceDirsFromTsConfig } from './tsconfig'
import { ProjectType } from './project'

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
  const allExist = () => true
  const noneExist = () => false

  it('extracts directories from include patterns', () => {
    const tsConfig = {
      include: ['src/**/*.ts', 'lib/**/*.tsx'],
    }

    const dirs = getSourceDirsFromTsConfig(tsConfig, allExist)

    expect(dirs).toEqual(['src', 'lib'])
  })

  it('returns empty array when tsconfig has no include field', () => {
    const dirs = getSourceDirsFromTsConfig({}, allExist)

    expect(dirs).toEqual([])
  })

  it('deduplicates directories from multiple patterns with same root', () => {
    const tsConfig = {
      include: ['src/**/*.ts', 'src/**/*.tsx'],
    }

    const dirs = getSourceDirsFromTsConfig(tsConfig, allExist)

    expect(dirs).toEqual(['src'])
  })

  it('skips bare globs like ** and file entries like next-env.d.ts', () => {
    const tsConfig = {
      include: ['next-env.d.ts', '**/*.ts', '**/*.tsx', 'components/**/*.ts'],
    }

    const dirs = getSourceDirsFromTsConfig(tsConfig, allExist)

    expect(dirs).toEqual(['components'])
  })

  it('skips glob-only patterns like *.ts', () => {
    const tsConfig = {
      include: ['*.config.ts', 'src/**/*.ts'],
    }

    const dirs = getSourceDirsFromTsConfig(tsConfig, allExist)

    expect(dirs).toEqual(['src'])
  })

  it('filters out directories that do not exist', () => {
    const tsConfig = {
      include: ['src/**/*.ts', 'lib/**/*.ts', 'tests/**/*.ts'],
    }
    const existing = new Set(['src', 'tests'])

    const dirs = getSourceDirsFromTsConfig(tsConfig, dir => existing.has(dir))

    expect(dirs).toEqual(['src', 'tests'])
  })

  it('adds pages and app dirs for Next.js projects when they exist', () => {
    const tsConfig = {
      include: ['src/**/*.ts'],
    }
    const existing = new Set(['src', 'pages', 'app'])

    const dirs = getSourceDirsFromTsConfig(tsConfig, dir => existing.has(dir), ProjectType.NextJs)

    expect(dirs).toEqual(['src', 'pages', 'app'])
  })

  it('does not duplicate pages/app if already extracted from include', () => {
    const tsConfig = {
      include: ['pages/**/*.tsx', 'app/**/*.tsx', 'src/**/*.ts'],
    }

    const dirs = getSourceDirsFromTsConfig(tsConfig, allExist, ProjectType.NextJs)

    expect(dirs).toEqual(['pages', 'app', 'src'])
  })

  it('does not add pages/app for Next.js if they do not exist', () => {
    const tsConfig = {
      include: ['src/**/*.ts'],
    }
    const existing = new Set(['src'])

    const dirs = getSourceDirsFromTsConfig(tsConfig, dir => existing.has(dir), ProjectType.NextJs)

    expect(dirs).toEqual(['src'])
  })

  it('does not add pages/app for generic projects', () => {
    const tsConfig = {
      include: ['src/**/*.ts'],
    }
    const existing = new Set(['src', 'pages', 'app'])

    const dirs = getSourceDirsFromTsConfig(tsConfig, dir => existing.has(dir), ProjectType.Generic)

    expect(dirs).toEqual(['src'])
  })
})

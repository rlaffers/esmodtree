import { resolve } from 'node:path'
import ts from 'typescript'
import { describe, expect, it } from 'vitest'
import { fileImportsSymbol, getExportedSymbols } from '../symbols'

const fixturesDir = resolve(import.meta.dirname, 'fixtures')
const fixture = (name: string) => resolve(fixturesDir, name)

const compilerOptions: ts.CompilerOptions = {
  module: ts.ModuleKind.NodeNext,
  moduleResolution: ts.ModuleResolutionKind.NodeNext,
  target: ts.ScriptTarget.ESNext,
  allowJs: true,
}

describe('getExportedSymbols', () => {
  it('extracts named function exports', () => {
    const symbols = getExportedSymbols(fixture('exports.ts'))
    expect(symbols).toContain('MyFunction')
  })

  it('extracts named class exports', () => {
    const symbols = getExportedSymbols(fixture('exports.ts'))
    expect(symbols).toContain('MyClass')
  })

  it('extracts const/let exports', () => {
    const symbols = getExportedSymbols(fixture('exports.ts'))
    expect(symbols).toContain('MY_CONST')
    expect(symbols).toContain('myLet')
  })

  it('extracts type and interface exports', () => {
    const symbols = getExportedSymbols(fixture('exports.ts'))
    expect(symbols).toContain('MyType')
    expect(symbols).toContain('MyInterface')
  })

  it('extracts enum exports', () => {
    const symbols = getExportedSymbols(fixture('exports.ts'))
    expect(symbols).toContain('MyEnum')
  })

  it('extracts aliased exports', () => {
    const symbols = getExportedSymbols(fixture('exports.ts'))
    expect(symbols).toContain('AliasedExport')
  })

  it('does not include non-exported symbols', () => {
    const symbols = getExportedSymbols(fixture('exports.ts'))
    expect(symbols).not.toContain('notExported')
    expect(symbols).not.toContain('alsoNotExported')
  })

  it('extracts re-exports with their exported names', () => {
    const symbols = getExportedSymbols(fixture('re-exports.ts'))
    expect(symbols).toContain('MyFunction')
    expect(symbols).toContain('MyClass')
    expect(symbols).toContain('RenamedConst')
  })
})

describe('fileImportsSymbol', () => {
  const target = fixture('exports.ts')

  it('returns true when the file imports the symbol by name', () => {
    const result = fileImportsSymbol(
      fixture('imports-named.ts'),
      target,
      'MyFunction',
      compilerOptions,
    )
    expect(result).toBe(true)
  })

  it('returns true for another named import from the same statement', () => {
    const result = fileImportsSymbol(
      fixture('imports-named.ts'),
      target,
      'MyClass',
      compilerOptions,
    )
    expect(result).toBe(true)
  })

  it('returns false when the file imports a different symbol from the target', () => {
    const result = fileImportsSymbol(
      fixture('imports-other.ts'),
      target,
      'MyFunction',
      compilerOptions,
    )
    expect(result).toBe(false)
  })

  it('returns true for namespace imports (import * as X)', () => {
    const result = fileImportsSymbol(
      fixture('imports-namespace.ts'),
      target,
      'MyFunction',
      compilerOptions,
    )
    expect(result).toBe(true)
  })

  it('returns true when the symbol is imported with an alias', () => {
    const result = fileImportsSymbol(
      fixture('imports-aliased.ts'),
      target,
      'MyFunction',
      compilerOptions,
    )
    expect(result).toBe(true)
  })

  it('returns false when the file does not import from the target at all', () => {
    const result = fileImportsSymbol(
      fixture('imports-none.ts'),
      target,
      'MyFunction',
      compilerOptions,
    )
    expect(result).toBe(false)
  })

  it('returns true for `export * from` re-exports', () => {
    const result = fileImportsSymbol(
      fixture('reexports-star.ts'),
      target,
      'MyFunction',
      compilerOptions,
    )
    expect(result).toBe(true)
  })

  it('returns true for `export * as NS from` namespace re-exports', () => {
    const result = fileImportsSymbol(
      fixture('reexports-namespace.ts'),
      target,
      'MyFunction',
      compilerOptions,
    )
    expect(result).toBe(true)
  })

  it('returns true for named re-exports matching the symbol', () => {
    const result = fileImportsSymbol(
      fixture('re-exports.ts'),
      target,
      'MyFunction',
      compilerOptions,
    )
    expect(result).toBe(true)
  })

  it('matches aliased re-exports against the original name, not the alias', () => {
    const aliased = fileImportsSymbol(
      fixture('reexports-aliased.ts'),
      target,
      'MyFunction',
      compilerOptions,
    )
    expect(aliased).toBe(true)

    const byAlias = fileImportsSymbol(
      fixture('reexports-aliased.ts'),
      target,
      'fn',
      compilerOptions,
    )
    expect(byAlias).toBe(false)
  })

  it('returns false when named re-exports do not include the symbol', () => {
    const result = fileImportsSymbol(fixture('re-exports.ts'), target, 'myLet', compilerOptions)
    expect(result).toBe(false)
  })
})

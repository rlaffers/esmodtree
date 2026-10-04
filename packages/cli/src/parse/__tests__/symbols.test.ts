import { resolve } from 'node:path'
import * as ts from 'typescript'
import { describe, expect, it } from 'vitest'
import { analyzeSymbolLink, fileImportsSymbol, getExportedSymbols } from '../symbols'

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

describe('analyzeSymbolLink', () => {
  const target = fixture('exports.ts')
  const analyze = (file: string, names: string[] = ['MyFunction']) =>
    analyzeSymbolLink(fixture(file), target, names, compilerOptions)

  it('returns undefined when the file does not import the target at all', () => {
    expect(analyze('imports-none.ts')).toBeUndefined()
  })

  it('locates the first usage after a named import', () => {
    expect(analyze('imports-named.ts')?.reference).toEqual({ line: 3, column: 13, kind: 'usage' })
  })

  it('locates the usage of the alias for aliased imports', () => {
    expect(analyze('imports-aliased.ts')?.reference).toEqual({ line: 3, column: 13, kind: 'usage' })
  })

  it('locates NS.symbol for namespace imports', () => {
    expect(analyze('imports-namespace.ts')?.reference).toEqual({
      line: 3,
      column: 13,
      kind: 'usage',
    })
  })

  it('skips type-only positions and finds the first value usage', () => {
    const link = analyze('ref-type-then-value.ts', ['MyClass'])
    expect(link?.reference).toEqual({ line: 9, column: 26, kind: 'usage' })
  })

  it('treats `class extends` as a value usage', () => {
    expect(analyze('ref-extends.ts', ['MyClass'])?.reference).toEqual({
      line: 3,
      column: 17,
      kind: 'usage',
    })
  })

  it('ignores property keys and member names', () => {
    expect(analyze('ref-property-key.ts')?.reference).toEqual({ line: 5, column: 1, kind: 'usage' })
  })

  it('falls back to the import specifier when only type-only usage exists', () => {
    const link = analyze('ref-type-only.ts')
    expect(link?.matched).toBe(true)
    expect(link?.reference).toEqual({ line: 1, column: 15, kind: 'import' })
  })

  it('falls back to the import specifier when the import is unused', () => {
    expect(analyze('ref-unused.ts')?.reference).toEqual({ line: 1, column: 10, kind: 'import' })
  })

  it('reports columns as UTF-8 byte offsets', () => {
    expect(analyze('ref-multibyte.ts')?.reference).toEqual({ line: 3, column: 30, kind: 'usage' })
  })

  it('reports local re-exports of an import in exposedAs', () => {
    const link = analyze('ref-local-reexport.ts')
    expect(link?.reference).toEqual({ line: 3, column: 10, kind: 'usage' })
    expect(link?.exposedAs).toEqual(['Renamed'])
  })

  it('points at the export specifier for aliased re-exports and exposes the alias', () => {
    const link = analyze('reexports-aliased.ts')
    expect(link?.reference).toEqual({ line: 1, column: 24, kind: 'import' })
    expect(link?.exposedAs).toEqual(['fn'])
  })

  it('exposes the same names for `export *`', () => {
    const link = analyze('reexports-star.ts')
    expect(link?.reference).toEqual({ line: 1, column: 1, kind: 'import' })
    expect(link?.exposedAs).toEqual(['MyFunction'])
  })

  it('exposes the namespace name for `export * as NS`', () => {
    expect(analyze('reexports-namespace.ts')?.exposedAs).toEqual(['Exp'])
  })

  it('falls back to the import statement when no tracked names are given', () => {
    const link = analyze('imports-named.ts', [])
    expect(link?.matched).toBe(false)
    expect(link?.reference.kind).toBe('import')
    expect(link?.exposedAs).toEqual([])
  })
})

import { readFileSync } from 'node:fs'
import ts from 'typescript'

function parseSourceFile(absPath: string): ts.SourceFile {
  const content = readFileSync(absPath, 'utf-8')
  const ext = absPath.split('.').pop() ?? ''
  const langMap: Record<string, ts.ScriptKind> = {
    ts: ts.ScriptKind.TS,
    tsx: ts.ScriptKind.TSX,
    js: ts.ScriptKind.JS,
    jsx: ts.ScriptKind.JSX,
    mts: ts.ScriptKind.TS,
    mjs: ts.ScriptKind.JS,
    cts: ts.ScriptKind.TS,
    cjs: ts.ScriptKind.JS,
  }
  return ts.createSourceFile(
    absPath,
    content,
    ts.ScriptTarget.Latest,
    /* setParentNodes */ true,
    langMap[ext] ?? ts.ScriptKind.TS,
  )
}

/**
 * Returns all named export identifiers from a source file.
 *
 * Recognises:
 *   export function Foo …
 *   export class Foo …
 *   export const/let/var Foo …
 *   export { Foo }            — named export list
 *   export { bar as Foo }     — aliased export (returns "Foo")
 *   export { Foo } from '…'  — re-export
 *
 * Does NOT include default exports.
 */
export function getExportedSymbols(absPath: string): string[] {
  const sf = parseSourceFile(absPath)
  const symbols: string[] = []

  for (const stmt of sf.statements) {
    const mods = ts.canHaveModifiers(stmt) ? ts.getModifiers(stmt) : undefined
    const isExported = mods?.some(m => m.kind === ts.SyntaxKind.ExportKeyword)

    // export function Foo / export class Foo
    if (
      isExported &&
      (ts.isFunctionDeclaration(stmt) || ts.isClassDeclaration(stmt)) &&
      stmt.name
    ) {
      symbols.push(stmt.name.text)
    }

    // export const/let/var Foo = …
    if (isExported && ts.isVariableStatement(stmt)) {
      for (const decl of stmt.declarationList.declarations) {
        if (ts.isIdentifier(decl.name)) {
          symbols.push(decl.name.text)
        }
      }
    }

    // export type Foo = … / export interface Foo { … }
    if (isExported && (ts.isTypeAliasDeclaration(stmt) || ts.isInterfaceDeclaration(stmt))) {
      symbols.push(stmt.name.text)
    }

    // export enum Foo { … }
    if (isExported && ts.isEnumDeclaration(stmt)) {
      symbols.push(stmt.name.text)
    }

    // export { Foo, bar as Baz } or export { Foo } from '…'
    if (ts.isExportDeclaration(stmt) && stmt.exportClause && ts.isNamedExports(stmt.exportClause)) {
      for (const el of stmt.exportClause.elements) {
        // The exported name is el.name; propertyName is the local name when aliased
        symbols.push(el.name.text)
      }
    }
  }

  return symbols
}

/**
 * Checks whether a file imports or re-exports a specific named symbol from a
 * target module.
 *
 * Uses `ts.resolveModuleName` to match import/export specifiers to the target
 * file, then checks if the named bindings include the symbol.
 *
 * Returns true for:
 *   - named imports matching the symbol (including aliased forms)
 *   - namespace imports (`import * as X from '…'`) — symbol is reachable as `X.symbol`
 *   - `export * from '…'` — propagates all named exports of the target
 *   - `export * as NS from '…'` — symbol reachable as `NS.symbol`
 *   - `export { foo } from '…'` / `export { foo as bar } from '…'` matching the
 *     original exported name
 */
export function fileImportsSymbol(
  importerAbsPath: string,
  targetAbsPath: string,
  symbol: string,
  compilerOptions: ts.CompilerOptions,
): boolean {
  const sf = parseSourceFile(importerAbsPath)
  const host = ts.createCompilerHost(compilerOptions)

  // Normalise target path for comparison (strip extension variants)
  const normaliseResolved = (p: string): string => p.replace(/\\/g, '/')

  const targetNorm = normaliseResolved(targetAbsPath)

  const specifierResolvesToTarget = (specifier: string): boolean => {
    const resolved = ts.resolveModuleName(specifier, importerAbsPath, compilerOptions, host)
    const resolvedPath = resolved.resolvedModule?.resolvedFileName
    if (!resolvedPath) return false
    return normaliseResolved(resolvedPath) === targetNorm
  }

  for (const stmt of sf.statements) {
    if (ts.isImportDeclaration(stmt)) {
      if (!ts.isStringLiteral(stmt.moduleSpecifier)) continue
      if (!specifierResolvesToTarget(stmt.moduleSpecifier.text)) continue

      const clause = stmt.importClause
      if (!clause) continue

      // Namespace import: import * as X from '…'
      if (clause.namedBindings && ts.isNamespaceImport(clause.namedBindings)) {
        return true
      }

      // Named imports: import { Foo, bar as Baz } from '…'
      if (clause.namedBindings && ts.isNamedImports(clause.namedBindings)) {
        for (const el of clause.namedBindings.elements) {
          // el.propertyName is the original export name when aliased: import { Foo as Bar }
          // el.name is the local binding
          const importedName = el.propertyName?.text ?? el.name.text
          if (importedName === symbol) {
            return true
          }
        }
      }
      continue
    }

    // Re-export forms: export * from '…', export * as NS from '…',
    // export { foo } from '…'
    if (ts.isExportDeclaration(stmt) && stmt.moduleSpecifier) {
      if (!ts.isStringLiteral(stmt.moduleSpecifier)) continue
      if (!specifierResolvesToTarget(stmt.moduleSpecifier.text)) continue

      // export * from '…' — no exportClause
      if (!stmt.exportClause) {
        return true
      }

      // export * as NS from '…'
      if (ts.isNamespaceExport(stmt.exportClause)) {
        return true
      }

      // export { foo, bar as baz } from '…' — match against original name
      if (ts.isNamedExports(stmt.exportClause)) {
        for (const el of stmt.exportClause.elements) {
          const originalName = el.propertyName?.text ?? el.name.text
          if (originalName === symbol) {
            return true
          }
        }
      }
    }
  }

  return false
}

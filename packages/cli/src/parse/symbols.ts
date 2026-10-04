import { readFileSync } from 'node:fs'
import * as ts from 'typescript'
import type { SymbolReference } from '~/graph/types'

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
 * Result of analysing how one file links to a target module.
 *
 * - `matched`: the file imports/re-exports at least one of the tracked names
 *   (namespace imports and `export *` count as matching).
 * - `reference`: where to look in the file. The first value-position usage
 *   after the import when there is one, otherwise the import/export statement.
 * - `exposedAs`: names under which the file re-exports the tracked symbol, so
 *   the next hop up the tree can keep tracking it.
 */
export type SymbolLink = {
  matched: boolean
  reference: SymbolReference
  exposedAs: string[]
}

function toReference(
  sf: ts.SourceFile,
  node: ts.Node,
  kind: SymbolReference['kind'],
): SymbolReference {
  const pos = node.getStart(sf)
  const { line } = sf.getLineAndCharacterOfPosition(pos)
  const lineStart = sf.getLineStarts()[line] ?? 0
  const column = Buffer.byteLength(sf.text.slice(lineStart, pos), 'utf8') + 1
  return { line: line + 1, column, kind }
}

/**
 * True when the identifier is a value reference rather than a declaration
 * name, a property key, or a member name that merely looks like the symbol.
 */
function isReferencePosition(id: ts.Identifier): boolean {
  const p = id.parent
  if (ts.isPropertyAccessExpression(p)) return p.expression === id
  if (ts.isQualifiedName(p)) return p.left === id
  if (ts.isExportSpecifier(p)) return p.propertyName ? p.propertyName === id : true
  if (ts.isBindingElement(p)) return p.propertyName !== id && p.name !== id
  if (
    ts.isPropertyAssignment(p) ||
    ts.isPropertyDeclaration(p) ||
    ts.isMethodDeclaration(p) ||
    ts.isGetAccessorDeclaration(p) ||
    ts.isSetAccessorDeclaration(p) ||
    ts.isEnumMember(p) ||
    ts.isJsxAttribute(p) ||
    ts.isVariableDeclaration(p) ||
    ts.isParameter(p) ||
    ts.isFunctionDeclaration(p) ||
    ts.isFunctionExpression(p) ||
    ts.isClassDeclaration(p) ||
    ts.isClassExpression(p)
  ) {
    return p.name !== id
  }
  return true
}

/** `class A extends Foo {}` is a value position, unlike `implements Foo`. */
function isClassExtendsClause(node: ts.Node): node is ts.ExpressionWithTypeArguments {
  return (
    ts.isExpressionWithTypeArguments(node) &&
    ts.isHeritageClause(node.parent) &&
    node.parent.token === ts.SyntaxKind.ExtendsKeyword &&
    ts.isClassLike(node.parent.parent)
  )
}

/**
 * Finds the first value-position occurrence of any of `locals` (or `NS.name`
 * for `namespaces`) in the file. Import declarations, re-exports with a module
 * specifier, and every type-only position are ignored.
 */
function findFirstUsage(
  sf: ts.SourceFile,
  locals: Set<string>,
  namespaces: Set<string>,
  names: string[],
): ts.Node | undefined {
  let usage: ts.Node | undefined

  const visit = (node: ts.Node): void => {
    if (usage) return
    if (ts.isImportDeclaration(node) || ts.isImportEqualsDeclaration(node)) return
    if (ts.isExportDeclaration(node) && (node.isTypeOnly || node.moduleSpecifier)) return
    if (ts.isExportSpecifier(node) && node.isTypeOnly) return
    if (ts.isInterfaceDeclaration(node) || ts.isTypeAliasDeclaration(node)) return
    if (isClassExtendsClause(node)) {
      visit(node.expression)
      return
    }
    if (ts.isTypeNode(node)) return

    if (
      ts.isPropertyAccessExpression(node) &&
      ts.isIdentifier(node.expression) &&
      namespaces.has(node.expression.text) &&
      names.includes(node.name.text)
    ) {
      usage = node.expression
      return
    }
    if (ts.isIdentifier(node) && locals.has(node.text) && isReferencePosition(node)) {
      usage = node
      return
    }
    ts.forEachChild(node, visit)
  }

  visit(sf)
  return usage
}

/**
 * Analyses how `importerAbsPath` imports or re-exports the tracked `names`
 * from `targetAbsPath`. Returns undefined when no static import/export
 * statement in the file resolves to the target.
 *
 * Uses `ts.resolveModuleName` to match specifiers to the target file.
 * Matching rules:
 *   - named imports matching a name (including aliased forms)
 *   - namespace imports (`import * as X from '…'`) — symbol is reachable as `X.symbol`
 *   - `export * from '…'` — propagates all named exports of the target
 *   - `export * as NS from '…'` — symbol reachable as `NS.symbol`
 *   - `export { foo } from '…'` / `export { foo as bar } from '…'` matching the
 *     original exported name
 */
export function analyzeSymbolLink(
  importerAbsPath: string,
  targetAbsPath: string,
  names: string[],
  compilerOptions: ts.CompilerOptions,
): SymbolLink | undefined {
  const sf = parseSourceFile(importerAbsPath)
  const host = ts.createCompilerHost(compilerOptions)

  const normaliseResolved = (p: string): string => p.replace(/\\/g, '/')
  const targetNorm = normaliseResolved(targetAbsPath)

  const specifierResolvesToTarget = (specifier: string): boolean => {
    const resolved = ts.resolveModuleName(specifier, importerAbsPath, compilerOptions, host)
    const resolvedPath = resolved.resolvedModule?.resolvedFileName
    if (!resolvedPath) return false
    return normaliseResolved(resolvedPath) === targetNorm
  }

  let matched = false
  let matchedNode: ts.Node | undefined
  let fallbackNode: ts.Node | undefined
  const exposed = new Set<string>()
  // Local bindings of the tracked symbol: value-usable ones, and all (incl. type-only).
  const valueLocals = new Set<string>()
  const anyLocals = new Set<string>()
  const namespaces = new Set<string>()

  const markMatched = (node: ts.Node): void => {
    matched = true
    matchedNode ??= node
  }

  for (const stmt of sf.statements) {
    if (ts.isImportDeclaration(stmt)) {
      if (!ts.isStringLiteral(stmt.moduleSpecifier)) continue
      if (!specifierResolvesToTarget(stmt.moduleSpecifier.text)) continue
      fallbackNode ??= stmt.moduleSpecifier

      const clause = stmt.importClause
      if (!clause) continue
      const bindings = clause.namedBindings

      // import * as X from '…'
      if (bindings && ts.isNamespaceImport(bindings)) {
        markMatched(bindings.name)
        if (!clause.isTypeOnly) namespaces.add(bindings.name.text)
      }

      // import { Foo, bar as Baz } from '…'
      if (bindings && ts.isNamedImports(bindings)) {
        for (const el of bindings.elements) {
          const importedName = el.propertyName?.text ?? el.name.text
          if (!names.includes(importedName)) continue
          markMatched(el.name)
          anyLocals.add(el.name.text)
          if (!clause.isTypeOnly && !el.isTypeOnly) valueLocals.add(el.name.text)
        }
      }
      continue
    }

    if (ts.isExportDeclaration(stmt) && stmt.moduleSpecifier) {
      if (!ts.isStringLiteral(stmt.moduleSpecifier)) continue
      if (!specifierResolvesToTarget(stmt.moduleSpecifier.text)) continue
      fallbackNode ??= stmt.moduleSpecifier

      // export * from '…'
      if (!stmt.exportClause) {
        markMatched(stmt)
        for (const name of names) exposed.add(name)
        continue
      }

      // export * as NS from '…'
      if (ts.isNamespaceExport(stmt.exportClause)) {
        markMatched(stmt.exportClause.name)
        exposed.add(stmt.exportClause.name.text)
        continue
      }

      // export { foo, bar as baz } from '…' — match against original name
      if (ts.isNamedExports(stmt.exportClause)) {
        for (const el of stmt.exportClause.elements) {
          const originalName = el.propertyName?.text ?? el.name.text
          if (!names.includes(originalName)) continue
          markMatched(el.name)
          exposed.add(el.name.text)
        }
      }
    }
  }

  if (!fallbackNode) return undefined

  // import { Foo } from '…'; export { Foo as Bar } — local re-export of an import
  for (const stmt of sf.statements) {
    if (!ts.isExportDeclaration(stmt) || stmt.moduleSpecifier) continue
    if (!stmt.exportClause || !ts.isNamedExports(stmt.exportClause)) continue
    for (const el of stmt.exportClause.elements) {
      if (anyLocals.has(el.propertyName?.text ?? el.name.text)) exposed.add(el.name.text)
    }
  }

  const usage =
    valueLocals.size > 0 || namespaces.size > 0
      ? findFirstUsage(sf, valueLocals, namespaces, names)
      : undefined

  const reference = usage
    ? toReference(sf, usage, 'usage')
    : toReference(sf, matchedNode ?? fallbackNode, 'import')

  return { matched, reference, exposedAs: [...exposed] }
}

/**
 * Checks whether a file imports or re-exports a specific named symbol from a
 * target module. See `analyzeSymbolLink` for the matching rules.
 */
export function fileImportsSymbol(
  importerAbsPath: string,
  targetAbsPath: string,
  symbol: string,
  compilerOptions: ts.CompilerOptions,
): boolean {
  return (
    analyzeSymbolLink(importerAbsPath, targetAbsPath, [symbol], compilerOptions)?.matched ?? false
  )
}

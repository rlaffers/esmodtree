import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import ts from 'typescript'

const DEFAULT_COMPILER_OPTIONS: ts.CompilerOptions = {
  module: ts.ModuleKind.NodeNext,
  moduleResolution: ts.ModuleResolutionKind.NodeNext,
  target: ts.ScriptTarget.ESNext,
  allowJs: true,
  jsx: ts.JsxEmit.ReactJSX,
}

/**
 * Loads CompilerOptions from a tsconfig.json file, or returns sensible
 * defaults when no tsconfig is available.
 */
export function loadCompilerOptions(tsConfigPath?: string): ts.CompilerOptions {
  if (!tsConfigPath) {
    return DEFAULT_COMPILER_OPTIONS
  }

  const absPath = resolve(tsConfigPath)
  const configFile = ts.readConfigFile(absPath, path => readFileSync(path, 'utf-8'))

  if (configFile.error) {
    return DEFAULT_COMPILER_OPTIONS
  }

  const parsed = ts.parseJsonConfigFileContent(configFile.config, ts.sys, dirname(absPath))
  return parsed.options
}

import { existsSync, readFileSync } from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import { Command } from 'commander'
import { detectProjectType, detectSourceDirs } from '~/detect/project'
import { detectRootMarkers } from '~/detect/roots'
import { detectTsConfig, getSourceDirsFromTsConfig } from '~/detect/tsconfig'
import type { TsConfigContent } from '~/detect/tsconfig'
import { buildGraph } from '~/graph/build'
import { transformGraph } from '~/graph/transform'
import type { GraphData, ModuleMarker } from '~/graph/types'
import { VERSION } from '~/index'
import { formatJson } from '~/output/json'
import { formatTree } from '~/output/tree'
import { loadCompilerOptions } from '~/parse/compiler-options'
import { fileImportsSymbol, getExportedSymbols } from '~/parse/symbols'
import { traverseDown } from '~/traverse/down'
import { reverseTree } from '~/traverse/reverse'
import { traverseUp } from '~/traverse/up'
import type { ProjectType } from '~/detect/project'

/**
 * Produces per-module markers (e.g. route entry point, barrel) used to annotate
 * nodes in the output tree.
 */
function buildMarkers(projectType: ProjectType, graphData: GraphData): Map<string, ModuleMarker[]> {
  const modulePaths = [...graphData.adjacencyMaps.forward.keys()]
  const rootMarkers = detectRootMarkers(projectType, modulePaths)

  for (const [path, meta] of graphData.metadata) {
    if (meta.barrel) {
      const existing = rootMarkers.get(path) ?? []
      existing.push('barrel')
      rootMarkers.set(path, existing)
    }
  }

  return rootMarkers
}

export function createProgram(): Command {
  const program = new Command()

  program.name('esmodtree').description('ES module import tree visualizer').version(VERSION)

  program
    .option('--down <file>', 'show dependency tree (what this file imports)')
    .option('--updown <file>', 'show importer tree (what imports this file)')
    .option('--up <file>', 'show reversed importer tree (ancestors on top)')
    .option('--tsconfig <path>', 'path to tsconfig.json (skips auto-detection)')
    .option('--no-color', 'disable colored output')
    .option('--debug', 'show debug information')
    .option('--depth <n>', 'limit tree depth', parseInt)
    .option('--exclude <pattern>', 'exclude modules matching regex pattern')
    .option('--json', 'output as JSON instead of tree')
    .option('--root <dir>', 'source directory for --updown scans (skips auto-detection)')
    .option('--symbol <name>', 'filter by exported symbol name (use with --up or --updown)')
    .action(async options => {
      const down = options.down as string | undefined
      const updown = options.updown as string | undefined
      const up = options.up as string | undefined
      const useColor = options.color as boolean
      const tsconfigFlag = options.tsconfig as string | undefined
      const debug = options.debug as boolean | undefined
      const depthLimit = options.depth as number | undefined
      const excludePattern = options.exclude as string | undefined
      const jsonOutput = options.json as boolean | undefined
      const rootDir = options.root as string | undefined
      const symbolName = options.symbol as string | undefined
      const exclude = excludePattern ? new RegExp(excludePattern) : undefined

      if (!down && !updown && !up) {
        program.help()
        return
      }

      if (symbolName && down) {
        console.error('--symbol can only be used with --up or --updown')
        process.exitCode = 1
        return
      }

      if (symbolName && !updown && !up) {
        console.error('--symbol can only be used with --up or --updown')
        process.exitCode = 1
        return
      }

      const absTarget = resolve((down ?? updown ?? up)!)
      const tsConfigPath =
        tsconfigFlag ?? detectTsConfig(dirname(absTarget), { fileExists: existsSync })

      // Project root is the tsconfig's directory, or cwd as fallback
      const projectRoot = tsConfigPath ? dirname(resolve(tsConfigPath)) : process.cwd()
      const targetFile = relative(projectRoot, absTarget)
      // Make tsconfig path relative to project root for dep-cruiser
      const relTsConfigPath = tsConfigPath
        ? relative(projectRoot, resolve(tsConfigPath))
        : undefined

      const projectType = detectProjectType(file => existsSync(join(projectRoot, file)))

      if (debug) {
        console.log('[debug] cwd:', process.cwd())
        console.log('[debug] absTarget:', absTarget)
        console.log('[debug] tsConfigPath:', tsConfigPath ?? '(not found)')
        console.log('[debug] projectRoot:', projectRoot)
        console.log('[debug] targetFile:', targetFile)
        console.log('[debug] relTsConfigPath:', relTsConfigPath ?? '(none)')
        console.log('[debug] projectType:', projectType)
      }

      if (down) {
        const cruiseResult = await buildGraph([targetFile], {
          tsConfigPath: relTsConfigPath,
          cwd: projectRoot,
        })
        const graphData = transformGraph(cruiseResult)
        const markers = buildMarkers(projectType, graphData)
        const tree = traverseDown(targetFile, graphData.adjacencyMaps.forward, {
          markers,
          dependencyMetadata: graphData.dependencyMetadata,
          depth: depthLimit,
          exclude,
        })
        console.log(jsonOutput ? formatJson(tree) : formatTree(tree, { color: useColor }))
      }

      if (updown || up) {
        let sourceDirs: string[]

        if (rootDir) {
          sourceDirs = [rootDir]
        } else if (tsConfigPath) {
          const raw = readFileSync(tsConfigPath, 'utf-8')
          const tsConfig = JSON.parse(raw) as TsConfigContent
          sourceDirs = getSourceDirsFromTsConfig(
            tsConfig,
            dir => existsSync(join(projectRoot, dir)),
            projectType,
          )
        } else {
          sourceDirs = []
        }

        if (sourceDirs.length === 0) {
          sourceDirs = detectSourceDirs(dir => existsSync(join(projectRoot, dir)))
        }

        if (debug) {
          console.log('[debug] sourceDirs:', sourceDirs)
          console.log('[debug] tsconfig read from:', tsConfigPath)
        }

        if (sourceDirs.length === 0) {
          console.log('Could not detect source directories. Use --root to specify manually.')
          process.exitCode = 1
          return
        }

        // Validate --symbol: check the target file actually exports it
        let importsSymbolFilter: ((importerPath: string) => boolean) | undefined
        if (symbolName) {
          const exported = getExportedSymbols(absTarget)
          if (!exported.includes(symbolName)) {
            console.error(`Symbol "${symbolName}" is not exported from ${targetFile}`)
            process.exitCode = 1
            return
          }

          const compilerOptions = loadCompilerOptions(tsConfigPath)
          importsSymbolFilter = (importerRelPath: string) => {
            const importerAbsPath = resolve(projectRoot, importerRelPath)
            return fileImportsSymbol(importerAbsPath, absTarget, symbolName, compilerOptions)
          }

          if (debug) {
            console.log('[debug] symbol:', symbolName)
            console.log('[debug] exported symbols:', exported)
          }
        }

        const cruiseResult = await buildGraph(sourceDirs, {
          tsConfigPath: relTsConfigPath,
          cwd: projectRoot,
        })
        const graphData = transformGraph(cruiseResult)
        const markers = buildMarkers(projectType, graphData)
        const tree = traverseUp(targetFile, graphData.adjacencyMaps.reverse, {
          markers,
          dependencyMetadata: graphData.dependencyMetadata,
          depth: depthLimit,
          exclude,
          importsSymbol: importsSymbolFilter,
        })

        if (up) {
          const forest = reverseTree(tree)
          console.log(jsonOutput ? formatJson(forest) : formatTree(forest, { color: useColor }))
        } else {
          console.log(jsonOutput ? formatJson(tree) : formatTree(tree, { color: useColor }))
        }
      }
    })

  return program
}

// Run CLI when executed directly (not imported for testing)
if (process.env['VITEST'] === undefined) {
  createProgram().parse()
}

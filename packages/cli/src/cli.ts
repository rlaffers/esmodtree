import { existsSync } from 'node:fs'
import { relative } from 'node:path'
import { Command } from 'commander'
import { detectProjectType, detectSourceDirs } from '~/detect/project'
import { detectRootMarkers } from '~/detect/roots'
import { buildGraph } from '~/graph/build'
import { transformGraph } from '~/graph/transform'
import type { GraphData, ModuleMarker } from '~/graph/types'
import { VERSION } from '~/index'
import { formatTree } from '~/output/tree'
import { traverseDown } from '~/traverse/down'
import { traverseUp } from '~/traverse/up'
import type { ProjectType } from '~/detect/project'

function buildMarkers(projectType: ProjectType, graphData: GraphData): Map<string, ModuleMarker[]> {
  const modulePaths = [...graphData.adjacencyMaps.forward.keys()]
  const rootMarkers = detectRootMarkers(projectType, modulePaths)

  // Merge barrel markers from graph metadata
  for (const [path, meta] of graphData.metadata) {
    if (meta.barrel) {
      const existing = rootMarkers.get(path) ?? []
      existing.push('barrel')
      rootMarkers.set(path, existing)
    }
  }

  return rootMarkers
}

const program = new Command()

program.name('esmodtree').description('ES module import tree visualizer').version(VERSION)

program
  .option('--down <file>', 'show dependency tree (what this file imports)')
  .option('--up <file>', 'show importer tree (what imports this file)')
  .option('--no-color', 'disable colored output')
  .action(async options => {
    const down = options.down as string | undefined
    const up = options.up as string | undefined
    const useColor = options.color as boolean

    if (!down && !up) {
      program.help()
      return
    }

    const projectType = detectProjectType(file => existsSync(file))

    if (down) {
      const targetFile = relative(process.cwd(), down)
      const cruiseResult = await buildGraph([targetFile])
      const graphData = transformGraph(cruiseResult)
      const markers = buildMarkers(projectType, graphData)
      const tree = traverseDown(targetFile, graphData.adjacencyMaps.forward, {
        markers,
        dependencyMetadata: graphData.dependencyMetadata,
      })
      console.log(formatTree(tree, { color: useColor }))
    }

    if (up) {
      const targetFile = relative(process.cwd(), up)
      const sourceDirs = detectSourceDirs(dir => existsSync(dir))

      if (sourceDirs.length === 0) {
        console.error('Could not detect source directories. Use --root to specify manually.')
        process.exitCode = 1
        return
      }

      const cruiseResult = await buildGraph(sourceDirs)
      const graphData = transformGraph(cruiseResult)
      const markers = buildMarkers(projectType, graphData)
      const tree = traverseUp(targetFile, graphData.adjacencyMaps.reverse, {
        markers,
        dependencyMetadata: graphData.dependencyMetadata,
      })
      console.log(formatTree(tree, { color: useColor }))
    }
  })

program.parse()

import { existsSync } from 'node:fs'
import { relative } from 'node:path'
import { Command } from 'commander'
import { detectSourceDirs } from '~/detect/project'
import { buildGraph } from '~/graph/build'
import { transformGraph } from '~/graph/transform'
import { VERSION } from '~/index'
import { formatTree } from '~/output/tree'
import { traverseDown } from '~/traverse/down'
import { traverseUp } from '~/traverse/up'

const program = new Command()

program.name('esmodtree').description('ES module import tree visualizer').version(VERSION)

program
  .option('--down <file>', 'show dependency tree (what this file imports)')
  .option('--up <file>', 'show importer tree (what imports this file)')
  .action(async options => {
    const down = options.down as string | undefined
    const up = options.up as string | undefined

    if (!down && !up) {
      program.help()
      return
    }

    if (down) {
      const targetFile = relative(process.cwd(), down)
      const cruiseResult = await buildGraph([targetFile])
      const { adjacencyMaps } = transformGraph(cruiseResult)
      const tree = traverseDown(targetFile, adjacencyMaps.forward)
      console.log(formatTree(tree))
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
      const { adjacencyMaps } = transformGraph(cruiseResult)
      const tree = traverseUp(targetFile, adjacencyMaps.reverse)
      console.log(formatTree(tree))
    }
  })

program.parse()

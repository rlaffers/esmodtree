import { relative } from 'node:path'
import { Command } from 'commander'
import { buildGraph } from '~/graph/build'
import { transformGraph } from '~/graph/transform'
import { VERSION } from '~/index'
import { formatTree } from '~/output/tree'
import { traverseDown } from '~/traverse/down'

const program = new Command()

program.name('esmodtree').description('ES module import tree visualizer').version(VERSION)

program
  .option('--down <file>', 'show dependency tree (what this file imports)')
  .action(async options => {
    if (!options.down) {
      program.help()
      return
    }

    const targetFile = relative(process.cwd(), options.down as string)

    const cruiseResult = await buildGraph([targetFile])
    const { adjacencyMaps } = transformGraph(cruiseResult)
    const tree = traverseDown(targetFile, adjacencyMaps.forward)
    const output = formatTree(tree)

    console.log(output)
  })

program.parse()

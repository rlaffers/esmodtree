export const VERSION = '0.1.0'

export { detectSourceDirs } from '~/detect/project'
export { buildGraph } from '~/graph/build'
export { transformGraph } from '~/graph/transform'
export type { AdjacencyMaps, GraphData, ModuleMetadata, TreeNode } from '~/graph/types'
export { formatTree } from '~/output/tree'
export { traverseDown } from '~/traverse/down'
export { traverseUp } from '~/traverse/up'

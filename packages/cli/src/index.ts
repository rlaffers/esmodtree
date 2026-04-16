export const VERSION = '0.1.0'

export { detectProjectType, detectSourceDirs, ProjectType } from '~/detect/project'
export { detectRootMarkers } from '~/detect/roots'
export { buildGraph } from '~/graph/build'
export { transformGraph } from '~/graph/transform'
export type {
  AdjacencyMaps,
  GraphData,
  ModuleMarker,
  ModuleMetadata,
  TreeNode,
} from '~/graph/types'
export { formatTree } from '~/output/tree'
export { traverseDown } from '~/traverse/down'
export { traverseUp } from '~/traverse/up'

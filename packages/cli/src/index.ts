export const VERSION = '0.1.0'

export { detectProjectType, detectSourceDirs, ProjectType } from '~/detect/project'
export { detectRootMarkers } from '~/detect/roots'
export { detectTsConfig, getSourceDirsFromTsConfig } from '~/detect/tsconfig'
export type { DetectTsConfigOptions, TsConfigContent } from '~/detect/tsconfig'
export { buildGraph } from '~/graph/build'
export { transformGraph } from '~/graph/transform'
export type {
  AdjacencyMaps,
  DependencyFlags,
  DependencyMetadata,
  GraphData,
  ModuleMarker,
  ModuleMetadata,
  TreeNode,
} from '~/graph/types'
export { formatJson } from '~/output/json'
export { formatTree } from '~/output/tree'
export { traverseDown } from '~/traverse/down'
export { traverseUp } from '~/traverse/up'

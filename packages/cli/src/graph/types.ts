import type { ICruiseResult } from 'dependency-cruiser'

export type { ICruiseResult }

export type AdjacencyMaps = {
  forward: Map<string, string[]>
  reverse: Map<string, string[]>
}

export type ModuleMetadata = Map<string, { circular: boolean }>

export type GraphData = {
  adjacencyMaps: AdjacencyMaps
  metadata: ModuleMetadata
}

export type TreeNode = {
  path: string
  circular: boolean
  children: TreeNode[]
}

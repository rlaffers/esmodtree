import type { ICruiseResult } from 'dependency-cruiser'

export type { ICruiseResult }

export type ModuleMarker = 'page' | 'layout' | 'entry' | 'barrel' | 'dynamic'

export type ModuleMetadataEntry = {
  circular: boolean
  barrel: boolean
}

export type DependencyFlags = {
  dynamic: boolean
}

export type AdjacencyMaps = {
  forward: Map<string, string[]>
  reverse: Map<string, string[]>
}

export type ModuleMetadata = Map<string, ModuleMetadataEntry>
export type DependencyMetadata = Map<string, Map<string, DependencyFlags>>

export type GraphData = {
  adjacencyMaps: AdjacencyMaps
  metadata: ModuleMetadata
  dependencyMetadata: DependencyMetadata
}

export type TreeNode = {
  path: string
  circular: boolean
  markers: ModuleMarker[]
  children: TreeNode[]
}

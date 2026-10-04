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

/**
 * Location inside a file where it references the symbol being tracked.
 * `line` is 1-based and `column` is a 1-based UTF-8 byte offset (matching
 * Neovim's quickfix `col`). `kind` is 'usage' for the first value-position
 * occurrence after the import, or 'import' when only the import/export
 * statement itself could be located.
 */
export type SymbolReference = {
  line: number
  column: number
  kind: 'usage' | 'import'
}

export type TreeNode = {
  path: string
  circular: boolean
  markers: ModuleMarker[]
  children: TreeNode[]
  /** Where this file references the module on its path towards the queried file. */
  reference?: SymbolReference
}

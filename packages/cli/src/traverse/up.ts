import type { DependencyMetadata, ModuleMarker, SymbolReference, TreeNode } from '~/graph/types'

export type SymbolTracking = {
  /** Names under which the start file exposes the tracked symbol. */
  names: string[]
  /**
   * Called for every importer → imported edge. Returns where the importer
   * references the imported module, plus the names under which the importer
   * re-exports the symbol (used to keep tracking one hop further up).
   */
  analyze: (
    importerPath: string,
    importedPath: string,
    names: string[],
  ) => { reference: SymbolReference; exposedAs: string[] } | undefined
}

export type TraverseOptions = {
  markers?: Map<string, ModuleMarker[]>
  dependencyMetadata?: DependencyMetadata
  depth?: number
  exclude?: RegExp
  /**
   * When set, filters direct importers of the start file (depth 1) to only
   * those for which this callback returns true. Used by --symbol to keep only
   * importers that actually import a specific named export.
   */
  importsSymbol?: (importerPath: string) => boolean
  /** When set, annotates each importer node with its `reference` location. */
  symbolTracking?: SymbolTracking
}

/**
 * Builds an importer tree by walking the reverse adjacency map from a target file
 * up through all its direct and transitive importers. Each node is annotated with
 * markers (barrel, dynamic import, route entry point, etc.) and circular back-edges
 * are detected and short-circuited.
 */
export function traverseUp(
  startFile: string,
  reverse: Map<string, string[]>,
  options: TraverseOptions = {},
): TreeNode {
  const {
    markers = new Map(),
    dependencyMetadata = new Map(),
    depth: maxDepth,
    exclude,
    importsSymbol,
    symbolTracking,
  } = options
  const visited = new Set<string>()

  function walk(
    file: string,
    edgeMarkers: ModuleMarker[],
    currentDepth: number,
    names: string[],
  ): TreeNode {
    if (visited.has(file)) {
      return { path: file, circular: true, markers: edgeMarkers, children: [] }
    }

    if (maxDepth !== undefined && currentDepth >= maxDepth) {
      const nodeMarkers = [...edgeMarkers, ...(markers.get(file) ?? [])]
      return { path: file, circular: false, markers: nodeMarkers, children: [] }
    }

    visited.add(file)
    let importers = (reverse.get(file) ?? []).filter(imp => !exclude || !exclude.test(imp))
    // At depth 0→1 (direct importers of the start file), apply the symbol filter
    if (currentDepth === 0 && importsSymbol) {
      importers = importers.filter(imp => importsSymbol(imp))
    }
    const children = importers.map(imp => {
      const depEdgeMarkers: ModuleMarker[] = []
      // In --updown mode, the edge goes from importer → file
      // so check if importer dynamically imports this file
      if (dependencyMetadata.get(imp)?.get(file)?.dynamic) {
        depEdgeMarkers.push('dynamic')
      }
      const link = symbolTracking?.analyze(imp, file, names)
      const child = walk(imp, depEdgeMarkers, currentDepth + 1, link?.exposedAs ?? [])
      if (link) child.reference = link.reference
      return child
    })
    visited.delete(file)

    const nodeMarkers = [...edgeMarkers, ...(markers.get(file) ?? [])]
    return { path: file, circular: false, markers: nodeMarkers, children }
  }

  return walk(startFile, [], 0, symbolTracking?.names ?? [])
}

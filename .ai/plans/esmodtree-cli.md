# Plan: esmodtree CLI

> Source PRD: `.ai/prds/esmodtree-cli.md`

## Architectural decisions

Durable decisions that apply across all phases:

- **Monorepo**: pnpm workspaces, CLI package at `packages/cli/`
- **Package**: `@esmodtree/cli` v0.1.0, ESM (`"type": "module"`)
- **Bin entry**: `bin/esmodtree.js` → built CLI
- **Engine**: `dependency-cruiser` `cruise()` API for import parsing and resolution
- **CLI framework**: `commander` for argument parsing
- **Colors**: `picocolors` for terminal colors
- **Build**: Vite library mode for bundling, `tsc --noEmit` for type checking, Vitest for tests
- **CLI signature**: `esmodtree --up <file>` | `esmodtree --down <file>` with flags `--depth N`, `--root <dir>`, `--tsconfig <path>`, `--exclude <pattern>`, `--json`, `--no-color`
- **Data flow**: `cruise()` → flat `{source, dependencies[]}[]` → adjacency maps (forward + reverse) + per-module metadata → DFS traversal → `TreeNode` tree → ASCII or JSON output
- **Key types**: `AdjacencyMaps` (forward and reverse maps), `ModuleMetadata` (per-module flags), `TreeNode` (recursive tree structure for output)

---

## Phase 1: `--down` with ASCII output (happy path)

**User stories**: 2 (down tree), 5 (circular dependency handling), 17 (exclude node_modules)

### What to build

The minimal end-to-end pipeline: user runs `esmodtree --down <file>` and sees an ASCII dependency tree on stdout. This phase wires together every integration layer for the first time -- CLI argument parsing, dependency-cruiser invocation, graph transformation, DFS traversal, and tree rendering. The tree excludes node_modules by default and marks circular dependencies with `[circular]` to prevent infinite output. No project detection, no root labeling, no color -- just the core pipeline working end-to-end.

### Acceptance criteria

- [ ] `esmodtree --down <file>` prints an ASCII tree of the file's transitive dependencies to stdout
- [ ] node_modules dependencies are excluded from the tree
- [ ] Circular dependencies are detected, marked with `[circular]`, and the branch is truncated
- [ ] GraphTransformer has unit tests covering: simple chain, fan-out, circular deps
- [ ] Down TreeTraverser has unit tests covering: single chain, multiple branches, cycle detection/truncation
- [ ] TreeFormatter has unit tests covering: single node, deep chain, wide branching, `[circular]` marker

---

## Phase 2: `--up` with ASCII output

**User stories**: 1 (up tree), 18 (single tree rooted at target)

### What to build

Add the `--up` mode. User runs `esmodtree --up <file>` and sees a tree rooted at the target file with branches showing all modules that import it, transitively. This requires cruising the full project source (not just the target file) to discover all importers, then walking the reverse adjacency map. Source directories are detected using a simple fallback strategy (check for `src/`, `app/`, `pages/`, etc.) -- full tsconfig-based detection comes in Phase 5.

### Acceptance criteria

- [ ] `esmodtree --up <file>` prints an ASCII tree of all transitive importers, rooted at the target file
- [ ] The tree is a single rooted tree (not multiple disconnected trees)
- [ ] Source directories to scan are auto-detected using common directory patterns as fallback
- [ ] Up TreeTraverser has unit tests covering: single chain, multiple importer branches, cycle detection, no importers found (leaf output)
- [ ] Circular references in up traversal are marked `[circular]` and truncated

---

## Phase 3: Project detection and root labeling

**User stories**: 3 (root markers), 12 (auto-detect project type), 13 (pages router), 14 (app router), 15 (generic TS entry points)

### What to build

Detect whether the target project is Next.js (pages router, app router) or a generic TypeScript project. Classify modules as roots based on project type and annotate tree output with `[page]`, `[layout]`, or `[entry]` markers. For Next.js pages router: files in `pages/` are roots. For app router: `page.tsx` and `layout.tsx` in `app/` are roots. For generic TS: `src/index.ts`, `src/main.ts`, or `package.json#main`/`#exports` targets are entry points.

### Acceptance criteria

- [ ] Next.js projects are detected by presence of `next.config.*` files
- [ ] Pages router files (`pages/**/*.tsx` but not `_app.tsx`, `_document.tsx`) are flagged `[page]`
- [ ] App router files (`app/**/page.tsx`) are flagged `[page]`, (`app/**/layout.tsx`) are flagged `[layout]`
- [ ] Generic TS entry points (`src/index.ts`, `src/main.ts`, `package.json#main`) are flagged `[entry]`
- [ ] Markers appear in both `--up` and `--down` tree output
- [ ] RootDetector has unit tests for all project types and edge cases (`_app.tsx`, `_document.tsx` not flagged)

---

## Phase 4: Barrel and dynamic import markers

**User stories**: 4 (barrel detection), 6 (dynamic import markers)

### What to build

Annotate barrel files and dynamic imports in the tree output. Barrel detection uses the heuristic: filename is `index.{ts,tsx,js,jsx}` and dependency-cruiser reports it primarily contains re-exports. Dynamic imports are identified from dependency-cruiser's dependency type metadata. Both markers appear in the ASCII tree alongside any existing root markers.

### Acceptance criteria

- [ ] Barrel files are detected and flagged with `[barrel]` in tree output
- [ ] Dynamic imports (`import()`, `React.lazy`) are flagged with `[dynamic]`
- [ ] A module can have multiple markers (e.g. `[barrel] [page]`)
- [ ] GraphTransformer extracts barrel and dynamic metadata from dep-cruiser output
- [ ] TreeFormatter tests cover `[barrel]` and `[dynamic]` markers, including combinations

---

## Phase 5: tsconfig detection and path alias resolution

**User stories**: 8 (auto-detect tsconfig + path aliases), 19 (`--tsconfig` flag), 20 (auto-detect source dirs from tsconfig)

### What to build

Auto-detect the project's `tsconfig.json` and pass it to dependency-cruiser so path aliases (`@components/*`, `~/*`, etc.) resolve correctly. Add a `--tsconfig <path>` flag to override detection. Use tsconfig's `include`/`exclude` fields to determine source directories for `--up` scanning, replacing the simple fallback from Phase 2.

### Acceptance criteria

- [ ] tsconfig.json is auto-detected by walking up from the target file
- [ ] `--tsconfig <path>` overrides auto-detection
- [ ] Path aliases defined in tsconfig `paths` resolve correctly in the dependency graph
- [ ] Source directories for `--up` mode are derived from tsconfig `include`/`exclude` when available
- [ ] Falls back to common directory patterns when tsconfig doesn't specify `include`
- [ ] Integration test with a fixture project using path aliases verifies correct resolution

---

## Phase 6: CLI polish -- depth, exclude, root, color, JSON

**User stories**: 7 (`--depth`), 9 (`--root`), 10 (`--json`), 11 (`--exclude`), 21 (color + `--no-color`)

### What to build

Add remaining CLI flags. `--depth N` limits tree traversal depth. `--exclude <pattern>` filters modules by regex. `--root <dir>` overrides auto-detected source directories. `--json` switches output to structured JSON. Colored output is enabled by default (markers get distinct colors via picocolors), with `--no-color` to disable.

### Acceptance criteria

- [ ] `--depth N` truncates the tree at depth N in both `--up` and `--down` modes
- [ ] `--exclude <pattern>` filters matching modules from the tree
- [ ] `--root <dir>` overrides source directory detection for `--up` scans
- [ ] `--json` outputs a valid JSON tree structure to stdout
- [ ] Colored output is on by default; `--no-color` disables it
- [ ] TreeTraverser tests cover depth limiting
- [ ] JsonFormatter has unit tests covering tree serialization

---

## Phase 7: Build, bin entry point, and packaging

**User story**: 16 (npm install / npx usage)

### What to build

Wire up the Vite build config (library mode targeting Node, externalizing dependencies), the `bin/esmodtree.ts` shim that imports the built CLI, and verify the package works via `npx` and global install. Ensure `package.json` `bin`, `main`, `types`, and `files` fields are correct.

### Acceptance criteria

- [ ] `pnpm build` in `packages/cli/` produces a working bundle in `dist/`
- [ ] `bin/esmodtree.js` is executable and correctly invokes the CLI
- [ ] `pnpm typecheck` passes with no errors
- [ ] All tests pass via `pnpm test`
- [ ] The package can be run via `npx` from another project directory (local link or pack test)
- [ ] `index.ts` exports core functions (graph building, traversal, formatting) for programmatic use

# PRD: esmodtree CLI -- ES Module Import Tree Visualizer

## Problem Statement

When working on TypeScript/JavaScript projects (especially large React/Next.js codebases), developers frequently need to answer two questions:

1. **"Where is this component used?"** -- Given a module like `components/MyButton.tsx`, what are all the ancestor modules that import it, transitively, all the way up to page files or entry points?
2. **"What does this entry point depend on?"** -- Given a page or entry file, what is the full tree of modules it imports, recursively?

Existing tools either produce complex graphical output (dependency-cruiser's dot/SVG graphs) that is hard to scan quickly, or flat text lists that lose the hierarchical structure. There is no CLI tool that produces a clean, `tree`-style ASCII output showing the import chain for a specific module, with awareness of project conventions like Next.js page files, barrel re-exports, and TypeScript path aliases.

## Solution

Build `esmodtree`, a command line tool that generates `tree`-style ASCII dependency trees for TypeScript/JavaScript projects. It operates in two modes:

- **`--updown <file>`**: Shows all ancestors (importers) of a module, recursively, as a tree rooted at the target file with branches going upward through the import chain. Root modules (Next.js pages, entry points) are flagged.
- **`--up <file>`**: Shows the same importer tree but reversed, with ancestors on top.
- **`--down <file>`**: Shows all descendants (dependencies) of a module, recursively, as a standard dependency tree.

The tool uses dependency-cruiser's battle-tested programmatic API as its parsing/resolution engine, and adds a focused UX layer on top: tree-style output, project type detection, root module labeling, barrel file detection, and simplified CLI ergonomics.

### Example Output

```
esmodtree --updown components/MyButton.tsx

components/MyButton.tsx
├── features/checkout/CheckoutForm.tsx
│   └── pages/checkout.tsx [page]
├── features/dashboard/DashboardCard.tsx
│   ├── features/dashboard/index.ts [barrel]
│   │   └── pages/dashboard.tsx [page]
│   └── pages/admin.tsx [page]
└── components/index.ts [barrel]
    └── features/settings/SettingsPanel.tsx
        └── pages/settings.tsx [page]
```

```
esmodtree --down pages/dashboard.tsx

pages/dashboard.tsx [page]
├── features/dashboard/index.ts [barrel]
│   ├── features/dashboard/DashboardCard.tsx
│   │   └── components/MyButton.tsx
│   └── features/dashboard/DashboardChart.tsx
│       └── hooks/useChartData.ts [dynamic]
├── layouts/MainLayout.tsx
│   └── components/Sidebar.tsx
└── hooks/useAuth.ts
    └── utils/api.ts [circular]
```

## User Stories

1. As a developer, I want to run `esmodtree --updown components/MyButton.tsx` and see a tree of all modules that import MyButton (directly or transitively), so that I can understand the impact surface of changing that component.
2. As a developer, I want to run `esmodtree --down pages/dashboard.tsx` and see a tree of all modules that dashboard.tsx depends on (directly or transitively), so that I can understand the full dependency chain of a page.
3. As a developer, I want root modules (Next.js pages, layouts, entry points) to be visually flagged with markers like `[page]`, `[layout]`, or `[entry]`, so that I can immediately see where ancestor chains terminate at meaningful boundaries.
4. As a developer, I want barrel files (index.ts files that only re-export) to be flagged with `[barrel]`, so that I can distinguish pass-through modules from modules with actual logic.
5. As a developer, I want circular dependencies to be handled gracefully with a `[circular]` marker and branch truncation, so that the tool doesn't hang or produce infinite output.
6. As a developer, I want dynamic imports (`import('./Foo')`, `React.lazy`) to be included in the tree with a `[dynamic]` marker, so that I can see lazy-loaded dependency chains.
7. As a developer, I want to limit tree depth with `--depth N`, so that I can get a high-level overview of large dependency trees without being overwhelmed.
8. As a developer, I want the tool to auto-detect my tsconfig.json and respect path aliases (e.g. `@components/*`, `~/*`), so that imports resolve correctly without manual configuration.
9. As a developer, I want to override the auto-detected source root with `--root <dir>`, so that I can constrain the scan scope or handle non-standard project layouts.
10. As a developer, I want to pass `--json` to get structured JSON output, so that I can pipe the result into other tools (`jq`, scripts, CI checks).
11. As a developer, I want to exclude certain modules with `--exclude <pattern>` (regex), so that I can filter out noise (e.g. test files, generated code).
12. As a developer, I want the tool to auto-detect whether my project uses Next.js (pages router or app router) vs a generic TypeScript setup, so that root detection works correctly without configuration.
13. As a developer working on a Next.js pages router project, I want files in `pages/` to be detected as roots and flagged with `[page]`.
14. As a developer working on a Next.js app router project, I want `page.tsx` and `layout.tsx` files in `app/` to be detected as roots and flagged with `[page]` or `[layout]`.
15. As a developer working on a generic TypeScript project, I want `src/index.ts`, `src/main.ts`, or the file referenced by `package.json#main`/`package.json#exports` to be detected as entry points and flagged with `[entry]`.
16. As a developer, I want to install the tool globally via `npm install -g @esmodtree/cli` or run it via `npx @esmodtree/cli`, so that I can use it across multiple projects.
17. As a developer, I want the tool to only show project-internal modules by default (excluding node_modules), so that the output focuses on my own code.
18. As a developer, I want the `--updown` tree to be a single tree rooted at my target file with multiple branches (one per importer chain), so that I can see the full picture in one view.
19. As a developer, I want the tool to override the tsconfig path with `--tsconfig <path>`, so that I can point to a non-standard tsconfig location.
20. As a developer, I want the tool to auto-detect the source directories to scan (from tsconfig `include`/`exclude`, or fallback to common patterns like `src/`, `app/`, `pages/`, `components/`, `lib/`), so that `--updown` mode scans the right scope without manual configuration.
21. As a developer, I want colored output by default (with a `--no-color` flag to disable), so that markers like `[page]`, `[circular]`, `[barrel]`, `[dynamic]` are visually distinct.

## Implementation Decisions

### Repository Structure

The repository is a **pnpm monorepo** with workspaces. The CLI is the first (and currently only) package, published as `@esmodtree/cli`. This structure allows future packages (e.g. a VS Code extension, a programmatic API library) to be added alongside it.

```
esmodtree/                          # monorepo root
├── packages/
│   └── cli/                        # @esmodtree/cli package
│       ├── src/
│       │   ├── cli.ts
│       │   ├── index.ts
│       │   ├── graph/
│       │   │   ├── buildGraph.ts
│       │   │   ├── transform.ts
│       │   │   └── types.ts
│       │   ├── traverse/
│       │   │   ├── down.ts
│       │   │   └── up.ts
│       │   ├── detect/
│       │   │   ├── project.ts
│       │   │   ├── roots.ts
│       │   │   └── tsconfig.ts
│       │   └── output/
│       │       ├── tree.ts
│       │       └── json.ts
│       ├── bin/
│       │   └── esmodtree.ts
│       ├── test/
│       ├── package.json
│       ├── tsconfig.json
│       └── vite.config.ts
├── package.json                    # root: workspaces config
├── pnpm-workspace.yaml
└── tsconfig.json                   # root: shared TS base config
```

### Core Engine: dependency-cruiser

The tool uses dependency-cruiser's programmatic `cruise()` API as its parsing and resolution engine. This is preferred over the TypeScript LanguageService because:

- dependency-cruiser handles all import styles (ES6 static/dynamic, CommonJS, re-exports, barrel files) across all relevant file types (.ts, .tsx, .js, .jsx, .mjs, .cjs)
- It natively supports tsconfig path alias resolution via its `extractTSConfig` utility
- It's battle-tested (6.6k GitHub stars, 380+ releases)
- The TypeScript LanguageService is designed for symbol-level IDE features (completions, rename, go-to-definition) and is overkill for module-level import graph analysis. It requires complex `LanguageServiceHost` setup, is slower to start, and handles plain JS poorly.

### Module Architecture

The codebase is decomposed into modules that maximize testability by separating I/O from pure logic:

**GraphBuilder** (`graph/buildGraph.ts`): Thin wrapper around dependency-cruiser's `cruise()` function. Configures dep-cruiser with the correct tsconfig, include/exclude patterns, and scope. For `--down`, it cruises just the target file. For `--updown`, it cruises the full project source directories. This is the only module with a hard dependency on dependency-cruiser.

**GraphTransformer** (`graph/transform.ts`): Pure function. Converts dependency-cruiser's flat `{source, dependencies[]}[]` output into two adjacency maps (forward: module -> its dependencies; reverse: module -> its importers) plus per-module metadata (isBarrel, isDynamic). No I/O.

**TreeTraverser** (`traverse/up.ts`, `traverse/down.ts`): Pure functions. Perform DFS on the adjacency maps to produce a `TreeNode` tree structure. Handle cycle detection (marking nodes as `[circular]` and truncating branches), depth limiting, and both traversal directions. The `--updown` traverser walks the reverse adjacency map; the `--down` traverser walks the forward map.

**ProjectDetector** (`detect/project.ts`): Detects the project type by checking for Next.js config files (`next.config.*`), reading tsconfig `include`/`exclude` to determine source directories, and falling back to common directory patterns (`src/`, `app/`, `pages/`, etc.). Also locates the tsconfig.json path.

**RootDetector** (`detect/roots.ts`): Pure function. Given the project type and a list of module paths, classifies which modules are "roots" -- Next.js pages router files (`pages/**/*.tsx`), app router files (`app/**/page.tsx`, `app/**/layout.tsx`), or generic entry points (`src/index.ts`, `package.json#main`). Returns the root classification per module (page, layout, entry, or none).

**TreeFormatter** (`output/tree.ts`): Pure function. Renders a `TreeNode` tree into ASCII output using box-drawing characters (`├──`, `│`, `└──`). Applies color to markers via picocolors. Flags modules with `[page]`, `[layout]`, `[entry]`, `[barrel]`, `[circular]`, `[dynamic]` based on node metadata.

**JsonFormatter** (`output/json.ts`): Pure function. Serializes a `TreeNode` tree to structured JSON.

**CLI** (`cli.ts`): Thin orchestration shell. Parses arguments with commander, calls the modules above in sequence, prints output to stdout. No business logic.

### Build Toolchain

- **Vite** (library mode) for building the distributable CLI bundle
- **tsc** for type checking only (not for producing output)
- **Vitest** for tests

### Dependencies

- `dependency-cruiser` -- core parsing/resolution engine
- `commander` -- CLI argument parsing
- `picocolors` -- terminal colors (1.5kB, zero deps)

### Key Behaviors

- **`--updown` traversal scope**: Must cruise the full project source to discover all importers. Auto-detected from tsconfig `include`/`exclude` or common patterns. Overridable with `--root`.
- **`--down` traversal scope**: Only cruises the target file (dep-cruiser follows dependencies recursively from the entry point).
- **node_modules excluded by default**: Uses dep-cruiser's `doNotFollow` to skip external dependencies.
- **Barrel detection heuristic**: A module is flagged as `[barrel]` if its filename is `index.{ts,tsx,js,jsx}` and dependency-cruiser reports it primarily contains re-exports.
- **Cycle handling**: When a module is encountered that's already in the current DFS path, the node is added with `isCircular: true` and the branch is truncated.
- **Dynamic imports**: Included in the tree. Dependency-cruiser marks the dependency type, which is carried through to the `[dynamic]` marker.

## Testing Decisions

### Test Philosophy

Tests should verify **external behavior** (inputs and outputs) of modules, not implementation details. A good test for this project feeds a known data structure into a pure function and asserts the output matches expectations. Tests should not mock dependency-cruiser internals or assert on intermediate data structures.

### Modules Under Test

The following four modules are pure functions with no I/O and are highly unit testable:

1. **GraphTransformer** -- Feed it mock dependency-cruiser JSON output (the `{source, dependencies[]}[]` structure). Assert the resulting forward and reverse adjacency maps are correct. Test cases: simple chain, fan-out, fan-in, circular deps, dynamic imports, barrel files.

2. **TreeTraverser** (both up and down) -- Feed it adjacency maps and a target module. Assert the resulting `TreeNode` tree has the correct shape. Test cases: single chain, multiple branches, cycle detection/truncation, depth limiting, empty results (no importers found).

3. **RootDetector** -- Feed it a project type and a list of file paths. Assert the correct root classifications. Test cases: Next.js pages router files, app router files, generic entry points, non-root files, edge cases like `_app.tsx` and `_document.tsx` which should NOT be flagged as pages.

4. **TreeFormatter** -- Feed it `TreeNode` trees. Assert the output string matches expected ASCII tree output (snapshot-style tests). Test cases: single node, deep chain, wide branching, all marker types (`[page]`, `[barrel]`, `[circular]`, `[dynamic]`), combination of markers.

### Test Fixtures

Small TypeScript project fixtures under `packages/cli/test/fixtures/` for integration-level validation of GraphBuilder (verifying that dep-cruiser is configured correctly and produces expected results for known project structures).

## Out of Scope

- **Watch mode**: No file-watching or incremental re-analysis on file changes.
- **GraphViz/dot/SVG output**: dependency-cruiser already handles this well. esmodtree focuses on ASCII tree output.
- **Monorepo cross-package analysis**: The tool analyzes a single package/project at a time. Cross-workspace dependency analysis is deferred.
- **Browser/bundler-specific resolution**: No Webpack alias support beyond what tsconfig path aliases cover. dep-cruiser supports Webpack resolve config, but it's not exposed in esmodtree's CLI for now.
- **Re-export tracing**: The tool does not resolve through barrel files to show the "real" source module. Barrels are shown as-is but flagged with `[barrel]`. A `--resolve-barrels` flag may be added later.
- **VS Code extension**: The monorepo structure supports it, but building an extension is deferred.
- **Interactive/TUI mode**: No interactive tree browsing. Output is static.

## Further Notes

- **Performance for `--updown`**: Since `--updown` must cruise the entire project source, it will be slower on large codebases. dependency-cruiser's `--cache` option (which caches cruise results and invalidates on file change) should be leveraged. Users can also constrain scope with `--root`.
- **Programmatic API**: The `index.ts` export should expose the core functions (graph building, traversal, formatting) for programmatic use by other packages in the monorepo or external consumers. This is a future concern but the module separation already supports it.
- **npm publishing**: The package will be published as `@esmodtree/cli` with a `bin` entry pointing to the built CLI. Users install via `npm install -g @esmodtree/cli` or run via `npx @esmodtree/cli`.

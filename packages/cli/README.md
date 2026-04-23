# @esmodtree/cli

ES module import tree visualizer for the command line.

Produces `tree`-style ASCII dependency trees for TypeScript/JavaScript projects. Answers two questions fast:

- **Where is this module used?** — walk importers upward, all the way to entry points.
- **What does this entry point depend on?** — walk dependencies downward.

Built on [dependency-cruiser](https://github.com/sverweij/dependency-cruiser) with project-aware labelling for Next.js pages/layouts, barrel files, circular references, and dynamic imports.

## Install

```sh
npm install -g @esmodtree/cli
# or
npx @esmodtree/cli --down src/index.ts
```

Requires Node 22+. TypeScript 5+ is a peer dependency.

## Usage

```sh
esmodtree --down <file>     # what <file> imports (descendants)
esmodtree --updown <file>   # what imports <file> (ancestors, rooted at target)
esmodtree --up <file>       # same importer tree, reversed (ancestors on top)
```

### Example — `--updown`

```
$ esmodtree --updown components/MyButton.tsx

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

### Example — `--down`

```
$ esmodtree --down pages/dashboard.tsx

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

## Options

| Flag                  | Description                                                                |
| --------------------- | -------------------------------------------------------------------------- |
| `--tsconfig <path>`   | Path to `tsconfig.json` (skips auto-detection)                             |
| `--root <dir>`        | Source directory for `--updown`/`--up` scans (skips auto-detection)        |
| `--depth <n>`         | Limit tree depth                                                           |
| `--exclude <pattern>` | Exclude modules matching a regex pattern                                   |
| `--symbol <name>`     | Filter importers to those using a specific export (with `--up`/`--updown`) |
| `--json`              | Output JSON instead of ASCII tree                                          |
| `--no-color`          | Disable colored output                                                     |
| `--debug`             | Print debug information (detected paths, project type, source dirs)        |
| `-V`, `--version`     | Print version                                                              |
| `-h`, `--help`        | Print help                                                                 |

## Markers

| Marker       | Meaning                                                   |
| ------------ | --------------------------------------------------------- |
| `[page]`     | Next.js page (pages router file or app router `page.*`)   |
| `[layout]`   | Next.js `layout.*` in app router                          |
| `[entry]`    | Generic entry point (`src/index.ts`, `package.json#main`) |
| `[barrel]`   | Re-export-only `index.*` file                             |
| `[circular]` | Cycle detected; branch truncated                          |
| `[dynamic]`  | Imported via `import()` / `React.lazy`                    |

## Project detection

- Detects **Next.js** (pages router and app router) via `next.config.*`; otherwise treats the project as generic TypeScript.
- Locates `tsconfig.json` starting from the target file's directory; respects path aliases.
- Derives source directories from tsconfig `include`/`exclude`, falling back to common patterns (`src/`, `app/`, `pages/`, `components/`, `lib/`).
- `node_modules` is excluded by default.

Override any of the above with `--tsconfig` and `--root`.

## License

GPLv3.0. See [LICENSE](./LICENSE).

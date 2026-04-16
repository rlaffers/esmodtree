# AGENTS.md

## Project

ES Module import tree visualizer CLI. Early stage -- see `.ai/prds/esmodtree-cli.md` for the PRD and `.ai/plans/esmodtree-cli.md` for the phased implementation plan.

## Toolchain

- **mise** pins Node 25.9 and pnpm 10.33 (see `.mise.toml`)
- pnpm monorepo; single package at `packages/cli` (`@esmodtree/cli`)
- TypeScript 6 with **project references** (root `tsconfig.json` → `packages/cli`)
- Vite 8 library-mode build targeting Node 22, outputs ESM to `dist/`
- Vitest 4 (no custom config -- uses defaults)
- Prettier only (no ESLint)

## Commands

```sh
# From root
pnpm check              # format:check + typecheck (also runs as pre-commit hook)
pnpm test               # vitest run (all packages)
pnpm format             # prettier --write

# Per package (packages/cli)
pnpm --filter @esmodtree/cli build      # vite build
pnpm --filter @esmodtree/cli typecheck  # tsc -p tsconfig.json
pnpm --filter @esmodtree/cli test       # vitest run
```

## Conventions

- **Commits**: conventional commits enforced via commitlint (`commit-msg` hook). Use `feat:`, `fix:`, `chore:`, etc.
- **Pre-commit**: runs `pnpm check` (format + typecheck must pass).
- **Formatting**: no semicolons, single quotes, 100 char width, avoid parens on single arrow params. See `prettier.config.mjs`.
- **Path alias**: `~/` maps to `src/` inside `packages/cli` (configured in both `tsconfig.json` paths and Vite `resolve.alias`).
- **Build externals**: all bare imports and `node:` builtins are external. The `cli.js` entry gets a shebang automatically.

## Architecture

- `packages/cli/src/cli.ts` -- CLI entry point (bin)
- `packages/cli/src/index.ts` -- library entry point
- Core dependency: `dependency-cruiser` for graph extraction, `commander` for CLI, `picocolors` for terminal color
- Planned modules (per `.ai/plans/`): GraphBuilder, GraphTransformer, TreeTraverser, ProjectDetector, RootDetector, TreeFormatter, JsonFormatter

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

## Typescript Conventions

- prefer types over interfaces
- avoid use `any`
- avoid type assertions

## Lua Type Annotations

Lua files (in `packages/nvim-esmodtree/`) use [LuaCATS](https://luals.github.io/wiki/annotations/) annotations (`---@`) for type safety. Annotate all public functions and non-trivial locals with `---@param`, `---@return`, `---@alias`, `---@type`, `---@class`/`---@field` as appropriate. Use `?` suffix for optional params. Namespace custom aliases with `esmodtree.` prefix.

## Commit Conventions

- Use **conventional commits** format: `<type>(<scope>): <description>`
- Never commit without asking me with the `question` tool first!

## GitHub

Repo: `github.com/rlaffers/esmodtree`

Use the `gh` CLI for all GitHub interactions (issues, PRs, releases, CI status):

```sh
gh issue list
gh issue view <number>
gh pr list
gh pr view <number>
gh pr create --title "..." --body "..."
gh run list                  # CI workflow runs
gh run view <id>             # view run details / logs
gh release list
```

Authenticate via `GH_TOKEN` env var if `gh auth login` has not been run.

## Architecture

- `packages/cli/src/cli.ts` -- CLI entry point (bin)
- `packages/cli/src/index.ts` -- library entry point
- Core dependency: `dependency-cruiser` for graph extraction, `commander` for CLI, `picocolors` for terminal color
- Planned modules (per `.ai/plans/`): GraphBuilder, GraphTransformer, TreeTraverser, ProjectDetector, RootDetector, TreeFormatter, JsonFormatter
- `plugin/esmodtree.lua` (repo root) -- Neovim-plugin shim that redirects runtime to `packages/nvim-esmodtree/`. Exists so `{ "rlaffers/esmodtree" }` works with lazy.nvim and pack-style installs without requiring a custom `config` function in user dotfiles. Do not delete.

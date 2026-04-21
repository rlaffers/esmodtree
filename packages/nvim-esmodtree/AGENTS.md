# AGENTS.md — nvim-esmodtree

## What this is

A **pure Lua Neovim plugin** (no TypeScript). It wraps `@esmodtree/cli` by installing it locally and invoking it from within Neovim. Completely independent of the root pnpm/Vite/Vitest toolchain — root `pnpm check` and `pnpm test` do **not** cover this package.

Requires Neovim >= 0.10.

## Commands

```sh
# From packages/nvim-esmodtree/
make test          # only test command; runs plenary busted suite via headless nvim
stylua lua/        # format check/fix (CI uses stylua --check)
```

`make test` expands to:

```sh
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"
```

`PLENARY_DIR` env var overrides the plenary clone location (defaults to `/tmp/plenary.nvim`; auto-cloned on first run).

## Toolchain

- **Formatter**: StyLua — `.stylua.toml` (120 col, 2-space indent, `AutoPreferDouble` quotes). Not Prettier.
- **Test framework**: plenary.nvim Busted runner
- **No pnpm scripts** defined in `package.json`

## Architecture

- `plugin/esmodtree.lua` — Neovim autoloads this at startup; registers `:Esmodtree` user command
- `lua/esmodtree/init.lua` — public API: `setup(opts)`, `dispatch(subcmd)`, `complete()`
- `lua/esmodtree/runner.lua` — opens centered float window (80% max, `border="rounded"`, `q`/`<Esc>` to close)
- `lua/esmodtree/util.lua` — `get_plugin_root()`, `bin_path()`, `detect_pm()`
- CLI binary resolves to `<plugin_root>/node_modules/.bin/esmodtree`

## Quirks

- **`util.get_plugin_root()` is call-depth sensitive**: uses `debug.getinfo(2)` — assumes callers are exactly one level deep at `lua/esmodtree/<name>.lua`. An extra wrapper frame will silently return the wrong root.
- **`cli-version.txt` contains `"latest"`**, not a pinned semver. `:Esmodtree install` reads this file and does a live `pnpm info` / `npm view` call to resolve the actual version. The `package.json` `@esmodtree/cli` dep version is **not** what gets installed at runtime.
- **pnpm install uses `--ignore-workspace`** to avoid workspace protocol conflicts.
- CI matrix: Ubuntu × macOS × Windows × Neovim stable/nightly — Windows is included, watch for path separator issues.
- **Vimdoc is auto-generated** from `README.md` via `panvimdoc` (workflow `nvim-docs`), committed to `doc/` by `github-actions[bot]`. Do not hand-edit files under `doc/`. When editing docs, update `README.md` only.

## Testing conventions

- Each spec clears module cache in `before_each`: `package.loaded["esmodtree.*"] = nil`
- `tests/helpers.lua` provides stubs for `vim.notify`, `vim.fn.executable`, `vim.fn.filereadable`, `vim.fn.readfile`, `vim.system` — all return restore closures; push to `cleanups` table and call in `after_each`
- All `vim.system` calls use async callback + `vim.schedule`; use `h.drain()` (`vim.wait(200)`) in tests to flush pending callbacks
- `tests/minimal_init.lua` adds `tests/` to `package.path` — spec files can `require("helpers")` without prefix

## Commit conventions

- Conventional commits (`feat:`, `fix:`, `chore:`, etc.) enforced via commitlint
- **Never commit without asking first** (use `question` tool)

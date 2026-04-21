# PRD: nvim-esmodtree -- Neovim Plugin for ES Module Tree Visualization

## Problem Statement

When working in Neovim on TypeScript/JavaScript projects, developers must leave the editor to run `esmodtree` CLI commands in a terminal. There is no way to visualize import trees from within the editor for the file currently being edited. This context-switching disrupts the development flow, especially when repeatedly checking dependency chains during refactoring or code review.

## Solution

Build a Neovim plugin (`nvim-esmodtree`) that wraps the `@esmodtree/cli` package, providing an `:Esmodtree` command with subcommands (`down`, `up`, `install`). The plugin:

- Installs the CLI locally via `:Esmodtree install` (using pnpm if available, npm otherwise).
- Executes the CLI asynchronously against the current buffer's file.
- Displays the ASCII tree output in a centered floating window.

### Example Usage

```vim
" Install the CLI (one-time setup)
:Esmodtree install

" Show what the current file imports (dependency tree)
:Esmodtree down

" Show what imports the current file (importer tree)
:Esmodtree up
```

The floating window shows the ASCII tree output:

```
src/components/MyButton.tsx
├── src/features/checkout/CheckoutForm.tsx
│   └── src/pages/checkout.tsx [page]
└── src/components/index.ts [barrel]
    └── src/features/settings/SettingsPanel.tsx
        └── src/pages/settings.tsx [page]
```

Press `q` or `<Esc>` to close the float.

## User Stories

1. As a Neovim user, I want to run `:Esmodtree install` to install the CLI binary locally within the plugin directory, so that I don't need to manage a global npm install separately.
2. As a Neovim user, I want `:Esmodtree install` to prefer pnpm over npm when both are available, so that my preferred package manager is used.
3. As a Neovim user, I want `:Esmodtree install` to check that Node.js is available and show a clear error if it's missing, so that I understand why installation failed.
4. As a Neovim user, I want `:Esmodtree install` to verify the installed binary works by running `esmodtree --version` after installation, so that I have confidence the install succeeded.
5. As a Neovim user, I want `:Esmodtree install` to install a specific CLI version declared by the plugin (not just "latest"), so that the plugin and CLI versions stay compatible.
6. As a Neovim user, I want to run `:Esmodtree down` on a TS/JS file and see the dependency tree in a floating window, so that I can understand dependencies without leaving the editor.
7. As a Neovim user, I want to run `:Esmodtree up` on a TS/JS file and see the importer tree in a floating window, so that I can understand the impact surface of changes.
8. As a Neovim user, I want the floating window to be sized to fit content (capped at 80% of editor dimensions), so that small trees don't waste space and large trees are still readable.
9. As a Neovim user, I want to close the floating window with `q` or `<Esc>`.
10. As a Neovim user, I want to see a spinner/progress notification while the CLI is running, so that I know the command is executing.
11. As a Neovim user, I want errors to appear as `vim.notify` error messages rather than silently failing.
12. As a Neovim user, I want the plugin to check the CLI binary exists before running, showing a helpful error directing me to `:Esmodtree install` if missing.
13. As a Neovim user, I want tab completion on `:Esmodtree` to show available subcommands (`down`, `up`, `install`).
14. As a Neovim user, I want the plugin to require only `setup()` with no mandatory configuration, so I can start using it immediately.

## Implementation Decisions

### Plugin Structure

Lives at `packages/nvim-esmodtree/` in the esmodtree monorepo but is NOT part of the pnpm workspace (excluded via `pnpm-workspace.yaml`). Has a minimal `package.json` (`{"name": "nvim-esmodtree", "private": true}`) to anchor npm/pnpm installs to the plugin directory. The `pnpm add` command uses `--ignore-workspace` as additional protection against workspace hoisting.

### Module Architecture

Three Lua modules plus a bootstrap file:

- **`init`** (`lua/esmodtree/init.lua`): Plugin entry point. Exports `setup(opts)` which deep-merges user config with defaults (empty config for v1). Registers the `:Esmodtree` user command with subcommand dispatch (`down`, `up`, `install`) and tab completion. Dispatches to `runner` or `install` modules.

- **`install`** (`lua/esmodtree/install.lua`): Handles CLI installation. Reads the required version from `cli-version.txt` at the plugin root. Checks for `node` availability first (hard error if missing). Detects `pnpm` (preferred) or falls back to `npm`. Runs the install command asynchronously via `vim.system()` in the plugin's root directory. Verifies success with `esmodtree --version`. Reports progress and errors via `vim.notify`.

- **`runner`** (`lua/esmodtree/runner.lua`): Executes CLI commands asynchronously. Resolves the binary path by deriving the plugin root directory from the Lua source file path (`debug.getinfo`), then looking for `node_modules/.bin/esmodtree`. Before running, checks the binary exists and notifies with a helpful error if missing. Builds the command (`esmodtree --down <absolute_file_path> --no-color`). Shows a spinner notification using `vim.notify` with replace ID (compatible with nvim-notify if installed, falls back to static message otherwise). On success, opens a floating window. On failure (non-zero exit), notifies with error level.

- **`plugin/esmodtree.lua`**: Bootstrap file, auto-loaded by Neovim. Registers the `:Esmodtree` command pointing to `require('esmodtree')` dispatch logic.

### CLI Version Pinning

A plain text file `cli-version.txt` at the plugin root contains the required `@esmodtree/cli` version (e.g. `0.1.1`). The install module reads this file and runs `pnpm add @esmodtree/cli@<version>` (or `npm install @esmodtree/cli@<version>`). To bump the required version, update this file.

### CLI Binary Location

Installed to the plugin's own `node_modules/.bin/esmodtree` (plugin-local install). The plugin derives its own root directory at runtime using `debug.getinfo(1, 'S').source` to locate the Lua source file, then navigates up to the plugin root. This is the same pattern used by copilot.lua and markdown-preview.nvim.

### Command Mapping

The CLI uses flag-based options (`--down`, `--updown`), not positional subcommands. The Neovim command `:Esmodtree down` maps internally to `esmodtree --down <file>`. This translation happens in the runner module.

### Floating Window

- Created with `nvim_open_win` using `relative='editor'`, `border='rounded'`.
- Buffer is a scratch buffer (`buftype=nofile`, `bufhidden=wipe`, `modifiable=false` after content is set).
- Sized to content: width = longest line (capped at 80% editor width), height = line count (capped at 80% editor height). Centered in the editor.
- Buffer-local keymaps: `q` and `<Esc>` close the window.

### Async Execution

All CLI operations use `vim.system()` (requires Neovim 0.10+). This keeps the editor responsive during potentially slow `--updown` scans.

### Output Format

The CLI is invoked with `--no-color` to suppress ANSI escape codes, since they don't render in normal Neovim buffers. Plain ASCII tree output is displayed as-is.

### Error Handling Strategy

- **Missing Node.js**: `vim.notify('Esmodtree: node is not installed', ERROR)` during `:Esmodtree install`.
- **Missing binary at runtime**: `vim.notify('Esmodtree: CLI not found. Run :Esmodtree install', ERROR)` before any `down`/`up` command.
- **CLI non-zero exit**: `vim.notify('Esmodtree: ' .. stderr, ERROR)`. Float is not opened.
- **Empty output**: `vim.notify('Esmodtree: no results', WARN)`. Float is not opened.

### Loading Indicator

A spinner notification is shown via `vim.notify` with a replace ID. If nvim-notify is installed, this produces an animated spinner. Without nvim-notify, it shows a static "Running..." message. The notification is dismissed/replaced when the result arrives.

## Testing Decisions

Tests deferred for v1. Existing plenary-busted infrastructure retained for future use. When added, focus on `install.lua` and `runner.lua` (mocking `vim.system`, `vim.fn.executable`, `vim.api`).

## Out of Scope

- ftplugin directory (handled by plugin manager config)
- Custom syntax highlighting for tree output
- `--up` subcommand
- Exposing additional CLI flags (`--depth`, `--exclude`, `--json`, etc.)
- Auto-install on setup
- Global/PATH binary resolution
- Neovim < 0.10 support

## Further Notes

- Recommended lazy.nvim config: `{ 'rlaffers/esmodtree', cmd = { 'Esmodtree' }, ft = { 'typescript', 'javascript', 'typescriptreact', 'javascriptreact' }, opts = {} }`
- `node_modules/` must be added to the plugin's `.gitignore`
- Future: expose more CLI flags, `--up`, custom highlighting, `checkhealth` integration, lazy.nvim `build` hook for auto-install

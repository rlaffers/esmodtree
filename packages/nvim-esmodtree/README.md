# nvim-esmodtree

Neovim plugin for visualizing ECMAScript module import trees. Wraps the
[@esmodtree/cli](https://www.npmjs.com/package/@esmodtree/cli) package.

## Requirements

- Neovim >= 0.10
- Node.js
- pnpm (preferred) or npm

## Installation

### lazy.nvim (recommended)

```lua
{
  "rlaffers/esmodtree",
  cmd = { "Esmodtree" },
  ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  opts = {},
  config = function(plugin, opts)
    local subdir = plugin.dir .. "/packages/nvim-esmodtree"
    vim.opt.rtp:append(subdir)
    require("lazy.core.loader").packadd(subdir)
    require("esmodtree").setup(opts)
  end,
}
```

`cmd` registers the `:Esmodtree` command immediately at startup (so `:Esmodtree install`
works before opening any JS/TS file). `ft` auto-loads the plugin when a supported filetype
is opened.

**Why the extra `packadd` and `setup` calls?** This repo is a monorepo — the Neovim plugin
lives under `packages/nvim-esmodtree/`, not at the repo root. Appending the subdirectory
to `&runtimepath` alone is not enough: lazy.nvim only sources `plugin/` files located
directly under the plugin's root (`plugin.dir`), so `plugin/esmodtree.lua` (which registers
the `:Esmodtree` command) would never run. Calling `require("lazy.core.loader").packadd(subdir)`
forces lazy to source the subdirectory's `plugin/` files synchronously during `config`.
Additionally, when `config` is a function, lazy does not auto-apply `opts`, so
`require("esmodtree").setup(opts)` must be called explicitly. See
[lazy.nvim#183](https://github.com/folke/lazy.nvim/issues/183) for background.

### Other plugin managers

Install with any plugin manager that adds the plugin to the runtimepath. The `:Esmodtree`
command is registered automatically on startup via `plugin/esmodtree.lua`. Then call
`setup()` somewhere in your config:

```lua
require("esmodtree").setup()
```

## Configuration

`setup()` accepts an options table:

| Option       | Type      | Default | Description                                                                                                                                                      |
| ------------ | --------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `use_colors` | `boolean` | `true`  | Colorize file paths and markers in the floating window output.                                                                                                   |
| `fold_level` | `integer` | —       | Initial fold level for the floating window. Folds deeper than this level are closed when the window opens. Omit to keep all folds expanded (equivalent to `99`). |

Example:

```lua
require("esmodtree").setup({
  use_colors = false,
  fold_level = 1,  -- show only the first level of the tree; deeper nodes folded
})
```

When `use_colors` is `false`, no highlight groups are registered and no
extmarks are applied — both the float and the location list render as plain
text.

When `fold_level` is set, the floating window opens with folds above that
depth closed. You can still open and close individual folds with the standard
Neovim fold keys (`zo`, `zc`, `za`, `zM`, `zR`, etc.) as well as the `=`
mapping (bound to `za`) provided by the plugin.

## Usage

```vim
" Install the CLI (one-time setup)
:Esmodtree install

" Show what the current file imports (dependency tree)
:Esmodtree down

" Show what imports the current file (importer tree, target at root)
:Esmodtree updown

" Show what imports the current file (ancestors at root)
:Esmodtree up

" Check if the plugin is properly installed and configured
:Esmodtree check
```

`:Esmodtree install` installs the CLI binary locally within the plugin directory. It prefers
pnpm when available, falling back to npm.

`:Esmodtree down`, `:Esmodtree up`, and `:Esmodtree updown` display the tree output in a
centered floating window. Press `q` or `<Esc>` to close.

### Location list display

Prefix any tree subcommand with `l` to send the output to the window-local
[location list](https://neovim.io/doc/user/quickfix.html#location-list) instead
of a floating window:

```vim
:Esmodtree ldown          " dependency tree -> loclist
:Esmodtree lup            " importer tree -> loclist
:Esmodtree lupdown        " importer tree (target at root) -> loclist
:Esmodtree lup MyButton   " filtered by symbol -> loclist
```

The location list preserves the tree-drawing characters in the display text
and lets you jump to any file by pressing `<CR>` on its entry. Use `:lopen`,
`:lnext`, `:lprev` and friends to navigate.

### Filtering by symbol

When a file exports multiple symbols, you can filter the importer tree to only
show branches that import a specific named export:

```vim
" Show only importers of MyButton from the current file
:Esmodtree up MyButton
:Esmodtree updown MyButton
```

If the symbol is not exported from the current file, the CLI will report an
error. This option is only available for `up` and `updown` -- using it with
`down` will produce an error.

### Key mappings

The plugin provides `<Plug>` mappings that you can bind to your preferred keys.
These are registered when `setup()` is called.

```lua
vim.keymap.set("n", "<leader>k", "<Plug>(esmodtree-lupdown-symbol)")
vim.keymap.set("n", "<leader>K", "<Plug>(esmodtree-updown-symbol)")
vim.keymap.set("n", "<leader>kk", "<Plug>(esmodtree-updown)")
vim.keymap.set("n", "<leader>KK", "<Plug>(esmodtree-lupdown)")
vim.keymap.set("n", "<leader>kj", "<Plug>(esmodtree-ldown)")
vim.keymap.set("n", "<leader>KJ", "<Plug>(esmodtree-down)")
vim.keymap.set("n", "<leader>ki", "<Plug>(esmodtree-lup-symbol)")
vim.keymap.set("n", "<leader>KI", "<Plug>(esmodtree-up-symbol)")
vim.keymap.set("n", "<leader>ku", "<Plug>(esmodtree-lup)")
vim.keymap.set("n", "<leader>KU", "<Plug>(esmodtree-up)")
```

| Mapping                            | Description                                                                |
| ---------------------------------- | -------------------------------------------------------------------------- |
| `<Plug>(esmodtree-down)`           | Show dependency tree for current file                                      |
| `<Plug>(esmodtree-up)`             | Show importer tree for current file                                        |
| `<Plug>(esmodtree-updown)`         | Show importer tree (target at root) for current file                       |
| `<Plug>(esmodtree-up-symbol)`      | Show importer tree filtered to the symbol under cursor                     |
| `<Plug>(esmodtree-updown-symbol)`  | Show importer tree (target at root) filtered to the symbol under cursor    |
| `<Plug>(esmodtree-ldown)`          | Show dependency tree in the location list                                  |
| `<Plug>(esmodtree-lup)`            | Show importer tree in the location list                                    |
| `<Plug>(esmodtree-lupdown)`        | Show importer tree (target at root) in the location list                   |
| `<Plug>(esmodtree-lup-symbol)`     | Loclist importer tree filtered to the symbol under cursor                  |
| `<Plug>(esmodtree-lupdown-symbol)` | Loclist importer tree (target at root) filtered to the symbol under cursor |

## Highlights

Highlighting is only applied when `use_colors` is enabled (the default — see
[Configuration](#configuration)). The floating window and the location list
colorize each line by applying the following highlight
groups. They are registered with `default = true`, so a colorscheme or your
own `:highlight` overrides win:

| Group                     | Default           | Applies to                      |
| ------------------------- | ----------------- | ------------------------------- |
| `EsmodtreeDir`            | `Comment`         | directory prefix of a file path |
| `EsmodtreeFile`           | `bold`            | basename portion of a file path |
| `EsmodtreeMarkerEntry`    | `DiagnosticOk`    | `[entry]` marker                |
| `EsmodtreeMarkerPage`     | `Statement`       | `[page]` marker                 |
| `EsmodtreeMarkerLayout`   | `Function`        | `[layout]` marker               |
| `EsmodtreeMarkerBarrel`   | `DiagnosticHint`  | `[barrel]` marker               |
| `EsmodtreeMarkerDynamic`  | `DiagnosticWarn`  | `[dynamic]` marker              |
| `EsmodtreeMarkerCircular` | `DiagnosticError` | `[circular]` marker             |

Example override:

```lua
vim.api.nvim_set_hl(0, "EsmodtreeFile", { fg = "#ffffff", bold = true })
vim.api.nvim_set_hl(0, "EsmodtreeMarkerEntry", { link = "String" })
```

## Running tests

```sh
make test
```

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (cloned automatically
to `/tmp/plenary.nvim` on first run).

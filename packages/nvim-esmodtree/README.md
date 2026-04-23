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
  config = function(plugin)
    vim.opt.rtp:append(plugin.dir .. "/packages/nvim-esmodtree")
  end,
}
```

`cmd` registers the `:Esmodtree` command immediately at startup (so `:Esmodtree install`
works before opening any JS/TS file). `ft` auto-loads the plugin when a supported filetype
is opened.

### Other plugin managers

Install with any plugin manager that adds the plugin to the runtimepath. The `:Esmodtree`
command is registered automatically on startup via `plugin/esmodtree.lua`. Then call
`setup()` somewhere in your config:

```lua
require("esmodtree").setup()
```

## Configuration

`setup()` accepts an options table:

| Option       | Type      | Default | Description                                                    |
| ------------ | --------- | ------- | -------------------------------------------------------------- |
| `use_colors` | `boolean` | `true`  | Colorize file paths and markers in the floating window output. |

Example:

```lua
require("esmodtree").setup({
  use_colors = false,
})
```

When `use_colors` is `false`, no highlight groups are registered and no
extmarks are applied — both the float and the location list render as plain
text.

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
vim.keymap.set("n", "<leader>ed", "<Plug>(esmodtree-down)")
vim.keymap.set("n", "<leader>eu", "<Plug>(esmodtree-up)")
vim.keymap.set("n", "<leader>eU", "<Plug>(esmodtree-updown)")
vim.keymap.set("n", "<leader>es", "<Plug>(esmodtree-up-symbol)")
vim.keymap.set("n", "<leader>eS", "<Plug>(esmodtree-updown-symbol)")
vim.keymap.set("n", "<leader>eld", "<Plug>(esmodtree-ldown)")
vim.keymap.set("n", "<leader>elu", "<Plug>(esmodtree-lup)")
vim.keymap.set("n", "<leader>elU", "<Plug>(esmodtree-lupdown)")
vim.keymap.set("n", "<leader>els", "<Plug>(esmodtree-lup-symbol)")
vim.keymap.set("n", "<leader>elS", "<Plug>(esmodtree-lupdown-symbol)")
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

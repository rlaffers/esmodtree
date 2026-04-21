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
```

| Mapping                           | Description                                                             |
| --------------------------------- | ----------------------------------------------------------------------- |
| `<Plug>(esmodtree-down)`          | Show dependency tree for current file                                   |
| `<Plug>(esmodtree-up)`            | Show importer tree for current file                                     |
| `<Plug>(esmodtree-updown)`        | Show importer tree (target at root) for current file                    |
| `<Plug>(esmodtree-up-symbol)`     | Show importer tree filtered to the symbol under cursor                  |
| `<Plug>(esmodtree-updown-symbol)` | Show importer tree (target at root) filtered to the symbol under cursor |

## Running tests

```sh
make test
```

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (cloned automatically
to `/tmp/plenary.nvim` on first run).

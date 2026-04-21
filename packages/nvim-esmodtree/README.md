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

" Show what imports the current file (importer tree)
:Esmodtree up

" Check if the plugin is properly installed and configured
:Esmodtree check
```

`:Esmodtree install` installs the CLI binary locally within the plugin directory. It prefers
pnpm when available, falling back to npm.

`:Esmodtree down` and `:Esmodtree up` display the tree output in a centered floating
window. Press `q` or `<Esc>` to close.

## Running tests

```sh
make test
```

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (cloned automatically
to `/tmp/plenary.nvim` on first run).

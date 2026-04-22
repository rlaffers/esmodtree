# PRD: Location List Display for nvim-esmodtree

## Problem Statement

The nvim-esmodtree plugin currently displays dependency/importer trees only in a floating window. While floats are convenient for quick inspection, they lack integration with Neovim's native navigation workflow. Users cannot use the built-in location list keybindings (`:lnext`, `:lprev`, etc.) to step through the tree, and the float disappears on any interaction outside it. A location list display mode would let users keep the tree visible in a persistent split while jumping between files in the tree.

## Solution

Add a new set of subcommands (`:Esmodtree ldown`, `:Esmodtree lup`, `:Esmodtree lupdown`) that invoke the same CLI tree commands but display the output in Neovim's location list instead of a floating window. Each line in the location list preserves the visual tree-drawing characters (box-drawing Unicode) so the tree structure remains readable. Selecting an entry (pressing Enter) opens the corresponding file at line 1, column 1. Symbol-filtered variants (`:Esmodtree lup <symbol>`, `:Esmodtree lupdown <symbol>`) are also supported.

## User Stories

1. As a Neovim user, I want to view a dependency tree in a location list, so that I can keep the tree visible while navigating files.
2. As a Neovim user, I want to press Enter on a location list entry to jump to that file, so that I can quickly navigate the dependency graph.
3. As a Neovim user, I want the tree-drawing characters preserved in the location list, so that I can visually understand the tree structure.
4. As a Neovim user, I want `:Esmodtree ldown` to show the downstream dependency tree in a location list, so that I can browse imports from the current file.
5. As a Neovim user, I want `:Esmodtree lup` to show the upstream importer tree in a location list, so that I can see what imports the current file.
6. As a Neovim user, I want `:Esmodtree lupdown` to show the combined up/down tree in a location list, so that I can see both importers and dependencies.
7. As a Neovim user, I want `:Esmodtree lup MyComponent` to filter the upstream tree to a specific symbol, so that I can trace a single export through the codebase.
8. As a Neovim user, I want `:Esmodtree lupdown MyComponent` to filter the combined tree to a specific symbol in the location list.
9. As a Neovim user, I want `<Plug>(esmodtree-ldown)` to trigger the downstream loclist view from a keymap, so that I can bind it to a convenient key.
10. As a Neovim user, I want `<Plug>(esmodtree-lup)` to trigger the upstream loclist view from a keymap.
11. As a Neovim user, I want `<Plug>(esmodtree-lupdown)` to trigger the combined loclist view from a keymap.
12. As a Neovim user, I want `<Plug>(esmodtree-lup-symbol)` to trigger a symbol-filtered upstream loclist using the word under cursor.
13. As a Neovim user, I want `<Plug>(esmodtree-lupdown-symbol)` to trigger a symbol-filtered combined loclist using the word under cursor.
14. As a Neovim user, I want tab completion to include the new `ldown`, `lup`, and `lupdown` subcommands.
15. As a Neovim user, I want the location list window title to say "Esmodtree", so that I can identify its source.
16. As a Neovim user, I want lines that cannot be resolved to a file to still appear in the location list, so that the tree structure is not broken by missing entries.

## Implementation Decisions

- **Display mode parameter**: `M.run(subcmd, symbol, display)` gains a third parameter `display` which is `"float"` (default) or `"loclist"`. Existing callers are unaffected.
- **Prefix stripping in dispatch**: `dispatch()` maps `ldown` -> `run("down", symbol, "loclist")`, `lup` -> `run("up", symbol, "loclist")`, `lupdown` -> `run("updown", symbol, "loclist")`. The `l` prefix is stripped in `dispatch()`, not in `M.run`.
- **Path extraction**: A new function `extract_path(line)` strips UTF-8 box-drawing bytes and leading spaces from each tree line, then returns the first whitespace-delimited token as the file path. Returns `""` if no path can be extracted. Exposed as `M._extract_path` for testing.
- **Path resolution**: Relative paths from the CLI are resolved against `vim.fn.getcwd()` by Neovim's built-in location list behavior. No extra resolution logic needed.
- **Location list population**: Uses `vim.fn.setloclist(0, items)` followed by `vim.cmd("lopen")`. Each item is `{ filename = extracted_path, lnum = 1, col = 1, text = original_line }`. The `setloclist` call uses the action/what form to set the title to `"Esmodtree"`.
- **Unresolvable lines**: Lines where `extract_path` returns `""` are still included in the location list with an empty filename. This preserves the visual tree shape.
- **`open_loclist` placement**: Local function in `runner.lua`, alongside `open_float`.
- **Subcommands list**: `SUBCOMMANDS` in `init.lua` expanded with `"ldown"`, `"lup"`, `"lupdown"`.
- **`<Plug>` mappings**: 5 new mappings in `setup()`: `esmodtree-ldown`, `esmodtree-lup`, `esmodtree-lupdown`, `esmodtree-lup-symbol`, `esmodtree-lupdown-symbol`.

## Testing Decisions

- Tests should verify external behavior (loclist contents, routing), not implementation internals (except `_extract_path` which is explicitly exposed for this purpose).
- **`M._extract_path` tests**: Cover root line (`src/index.ts [entry]`), indented lines with tree-drawing chars, lines with annotations (`[barrel]`, `[circular]`, `[dynamic]`), and edge cases (empty string, whitespace-only).
- **`open_loclist` tests**: Verify that `vim.fn.setloclist` is called with correctly structured items (filename, lnum, col, text fields), and that `lopen` is invoked.
- **`M.run` routing tests**: Verify that `display = "loclist"` populates the location list instead of opening a float, and that `display = "float"` (or nil) still opens a float.
- **Prior art**: Existing `runner_spec.lua` tests use `helpers.lua` stubs (`stub_system`, `stub_filereadable`, `capture_notifications`) and `find_float_win()` for float detection. The loclist tests will follow the same patterns, using `vim.fn.getloclist(0)` to inspect results.

## Out of Scope

- Quickfix list support (only location list for now).
- Customizable `lnum`/`col` values (always line 1, column 1).
- Highlighting or syntax coloring in the location list window.
- Configurable location list height or position.
- Changes to the CLI tool output format.

## Further Notes

- The `l` prefix convention (`ldown`, `lup`, `lupdown`) was chosen to parallel the existing subcommands while being concise and memorable.
- The location list is window-local, so multiple windows can have different esmodtree results simultaneously.

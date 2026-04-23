-- Monorepo shim for lazy.nvim / pack-style installs.
--
-- The actual Neovim plugin lives under packages/nvim-esmodtree/. When this repo
-- is installed as a plugin (e.g. `{ "rlaffers/esmodtree" }` in lazy.nvim),
-- plugin managers treat the repo root as the plugin root and only source
-- plugin/*.lua from the top level. This shim bridges that gap: it appends the
-- real plugin subdirectory to &runtimepath and sources its plugin file so the
-- :Esmodtree command gets registered without requiring users to add a custom
-- `config` function to their lazy spec.
--
-- Do NOT remove this file. See AGENTS.md for context.

local sub = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/packages/nvim-esmodtree"

if not vim.tbl_contains(vim.opt.rtp:get(), sub) then
	vim.opt.rtp:append(sub)
end

vim.cmd.source(vim.fs.normalize(sub .. "/plugin/esmodtree.lua"))

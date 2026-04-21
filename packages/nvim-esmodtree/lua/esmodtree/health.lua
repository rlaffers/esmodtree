local util = require("esmodtree.util")

local M = {}

function M.check()
  vim.health.start("esmodtree")

  -- 1. Node.js
  if vim.fn.executable("node") ~= 1 then
    vim.health.error("`node` not found on PATH", { "Install Node.js >= 22" })
    return
  end
  local node_v = vim.trim(vim.fn.system({ "node", "--version" }))
  vim.health.ok("Node.js " .. node_v)

  -- 2. cli-version.txt
  local plugin_root = util.get_plugin_root()
  local required = util.read_version(plugin_root)
  if not required then
    vim.health.error("Could not read cli-version.txt", {
      "File expected at: " .. plugin_root .. "/cli-version.txt",
    })
    return
  end
  vim.health.info("Required CLI version: " .. required)

  -- 3. Binary exists
  local bin = util.bin_path(plugin_root)
  if vim.fn.filereadable(bin) ~= 1 then
    vim.health.error("CLI binary not found at " .. bin, { "Run `:Esmodtree install`" })
    return
  end
  vim.health.ok("CLI binary found")

  -- 4. Binary runs
  local result = vim.system({ bin, "--version" }):wait()
  if result.code ~= 0 then
    vim.health.error("CLI binary failed to run: " .. (result.stderr or ""))
    return
  end
  local installed = vim.trim(result.stdout or "")
  vim.health.ok("Installed CLI version: " .. installed)

  -- 5. Version match
  if required == "latest" then
    vim.health.info('Required version is "latest"; installed v' .. installed)
  elseif installed ~= required then
    vim.health.warn(
      "Version mismatch: installed v" .. installed .. ", required v" .. required,
      { "Run `:Esmodtree install`" }
    )
  else
    vim.health.ok("Version match confirmed (v" .. installed .. ")")
  end
end

return M

local util = require("esmodtree.util")

local M = {}

function M.run()
  local plugin_root = util.get_plugin_root()
  local bin = util.bin_path(plugin_root)

  if vim.fn.filereadable(bin) ~= 1 then
    vim.schedule(function()
      vim.notify("❌ Esmodtree: CLI not found. Run :Esmodtree install", vim.log.levels.ERROR)
    end)
    return
  end

  local required_version = util.read_version(plugin_root)
  if not required_version then
    vim.schedule(function()
      vim.notify("❌ Esmodtree: could not read cli-version.txt", vim.log.levels.ERROR)
    end)
    return
  end

  -- Get installed version
  vim.system({ bin, "--version" }, {}, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("❌ Esmodtree: failed to get CLI version: " .. (result.stderr or ""), vim.log.levels.ERROR)
        return
      end

      local installed_version = vim.trim(result.stdout or "")

      if required_version == "latest" then
        -- Resolve "latest" to actual version via package manager
        M._resolve_latest_and_compare(installed_version)
      else
        M._compare_versions(installed_version, required_version)
      end
    end)
  end)
end

--- Compare installed version against required version and notify
function M._compare_versions(installed, required)
  if installed == required then
    vim.notify("✅ Esmodtree is all set and ready to go. (CLI v" .. installed .. ")", vim.log.levels.INFO)
  else
    vim.notify(
      "❌ Esmodtree: version mismatch — installed v"
        .. installed
        .. ", required v"
        .. required
        .. ". Run :Esmodtree install",
      vim.log.levels.WARN
    )
  end
end

--- Resolve "latest" tag to actual version via npm/pnpm, then compare
function M._resolve_latest_and_compare(installed_version)
  local pm = util.detect_pm()
  if not pm then
    vim.notify("❌ Esmodtree: neither pnpm nor npm is available to resolve latest version", vim.log.levels.ERROR)
    return
  end

  local cmd
  if pm == "pnpm" then
    cmd = { "pnpm", "info", "@esmodtree/cli", "version" }
  else
    cmd = { "npm", "view", "@esmodtree/cli", "version" }
  end

  vim.system(cmd, {}, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("❌ Esmodtree: failed to resolve latest version: " .. (result.stderr or ""), vim.log.levels.ERROR)
        return
      end

      local latest_version = vim.trim(result.stdout or "")
      M._compare_versions(installed_version, latest_version)
    end)
  end)
end

return M

local util = require("esmodtree.util")

local M = {}

--- Build the install command for the given package manager
local function build_install_cmd(pm, version)
  local pkg = "@esmodtree/cli@" .. version
  if pm == "pnpm" then
    return { "pnpm", "add", "--ignore-workspace", pkg }
  else
    return { "npm", "install", pkg }
  end
end

function M.run()
  if vim.fn.executable("node") ~= 1 then
    vim.notify("Esmodtree: node is not installed", vim.log.levels.ERROR)
    return
  end

  local plugin_root = util.get_plugin_root()
  local version = util.read_version(plugin_root)
  if not version then
    vim.notify("Esmodtree: could not read cli-version.txt", vim.log.levels.ERROR)
    return
  end

  local pm = util.detect_pm()
  if not pm then
    vim.notify("Esmodtree: neither pnpm nor npm is available", vim.log.levels.ERROR)
    return
  end

  local cmd = build_install_cmd(pm, version)

  vim.notify("Esmodtree: installing CLI v" .. version .. " via " .. pm .. "...", vim.log.levels.INFO)

  vim.system(cmd, { cwd = plugin_root }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("Esmodtree: install failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
        return
      end

      -- Verify the binary works
      local bin = util.bin_path(plugin_root)
      vim.system({ bin, "--version" }, {}, function(verify_result)
        vim.schedule(function()
          if verify_result.code ~= 0 then
            vim.notify("Esmodtree: install succeeded but binary verification failed", vim.log.levels.ERROR)
            return
          end
          local ver = vim.trim(verify_result.stdout or "")
          vim.notify("Esmodtree: installed CLI v" .. ver, vim.log.levels.INFO)
        end)
      end)
    end)
  end)
end

return M

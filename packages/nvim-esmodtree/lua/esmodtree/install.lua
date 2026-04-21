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

--- Read USE_LOCAL_CLI flag from <plugin_root>/.env. Returns true if set to "true".
local function read_env_flag(plugin_root)
  local env_file = plugin_root .. "/.env"
  if vim.fn.filereadable(env_file) ~= 1 then
    return false
  end
  local lines = vim.fn.readfile(env_file)
  for _, line in ipairs(lines) do
    local key, val = line:match("^([%w_]+)=(.-)%s*$")
    if key == "USE_LOCAL_CLI" and val == "true" then
      return true
    end
  end
  return false
end

--- Dev code path: create a shell script wrapper pointing at the local dist build.
local function install_local(plugin_root)
  local cli_dist = vim.fn.fnamemodify(plugin_root .. "/../cli/dist/cli.js", ":p")

  if vim.fn.filereadable(cli_dist) ~= 1 then
    vim.notify(
      "Esmodtree: local CLI not found at " .. cli_dist .. ". Run `pnpm --filter @esmodtree/cli build` first.",
      vim.log.levels.ERROR
    )
    return
  end

  local bin_dir = plugin_root .. "/node_modules/.bin"
  vim.fn.mkdir(bin_dir, "p")

  local bin = util.bin_path(plugin_root)
  local lines = {
    "#!/bin/sh",
    'exec node "' .. cli_dist .. '" "$@"',
  }

  if vim.fn.writefile(lines, bin) ~= 0 then
    vim.notify("Esmodtree: failed to write local CLI wrapper", vim.log.levels.ERROR)
    return
  end

  vim.system({ "chmod", "+x", bin }, {}, function(chmod_result)
    vim.schedule(function()
      if chmod_result.code ~= 0 then
        vim.notify("Esmodtree: failed to make wrapper executable", vim.log.levels.ERROR)
        return
      end

      -- Verify the binary works
      vim.system({ bin, "--version" }, {}, function(verify_result)
        vim.schedule(function()
          if verify_result.code ~= 0 then
            vim.notify("Esmodtree: local install succeeded but binary verification failed", vim.log.levels.ERROR)
            return
          end
          local ver = vim.trim(verify_result.stdout or "")
          vim.notify("Esmodtree: using local CLI v" .. ver, vim.log.levels.INFO)
        end)
      end)
    end)
  end)
end

function M.run()
  if vim.fn.executable("node") ~= 1 then
    vim.notify("Esmodtree: node is not installed", vim.log.levels.ERROR)
    return
  end

  local plugin_root = util.get_plugin_root()

  if read_env_flag(plugin_root) then
    vim.notify("Esmodtree: USE_LOCAL_CLI=true detected, using local CLI build", vim.log.levels.INFO)
    install_local(plugin_root)
    return
  end

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

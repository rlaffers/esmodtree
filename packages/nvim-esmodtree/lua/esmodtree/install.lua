local M = {}

--- Resolve the plugin root directory from this file's location.
--- Navigates up from lua/esmodtree/install.lua to the plugin root.
local function get_plugin_root()
  local source = debug.getinfo(1, "S").source:sub(2) -- remove leading @
  -- source is <plugin_root>/lua/esmodtree/install.lua
  return vim.fn.fnamemodify(source, ":h:h:h")
end

--- Read the required CLI version from cli-version.txt
local function read_version(plugin_root)
  local version_file = plugin_root .. "/cli-version.txt"
  local lines = vim.fn.readfile(version_file)
  if #lines == 0 then
    return nil
  end
  return vim.trim(lines[1])
end

--- Detect the preferred package manager
local function detect_pm()
  if vim.fn.executable("pnpm") == 1 then
    return "pnpm"
  elseif vim.fn.executable("npm") == 1 then
    return "npm"
  end
  return nil
end

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

  local plugin_root = get_plugin_root()
  local version = read_version(plugin_root)
  if not version then
    vim.notify("Esmodtree: could not read cli-version.txt", vim.log.levels.ERROR)
    return
  end

  local pm = detect_pm()
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
      local bin = plugin_root .. "/node_modules/.bin/esmodtree"
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

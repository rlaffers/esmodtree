local M = {}

--- Resolve the plugin root directory from the caller's file location.
--- Must be called from a file at <plugin_root>/lua/esmodtree/<name>.lua
function M.get_plugin_root()
  -- Walk up the call stack to find the caller (skip this util module)
  local source = debug.getinfo(2, "S").source:sub(2) -- remove leading @
  -- source is <plugin_root>/lua/esmodtree/<caller>.lua
  return vim.fn.fnamemodify(source, ":h:h:h")
end

--- Read the required CLI version from cli-version.txt
function M.read_version(plugin_root)
  local version_file = plugin_root .. "/cli-version.txt"
  local lines = vim.fn.readfile(version_file)
  if #lines == 0 then
    return nil
  end
  return vim.trim(lines[1])
end

--- Detect the preferred package manager. Returns "pnpm" or "npm" or nil.
function M.detect_pm()
  if vim.fn.executable("pnpm") == 1 then
    return "pnpm"
  elseif vim.fn.executable("npm") == 1 then
    return "npm"
  end
  return nil
end

--- Return the absolute path to the CLI binary
function M.bin_path(plugin_root)
  return plugin_root .. "/node_modules/.bin/esmodtree"
end

return M

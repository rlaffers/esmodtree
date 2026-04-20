local M = {}

local SUBCOMMANDS = { "down", "up", "install" }

function M.setup(opts)
  opts = opts or {}
end

--- Dispatch a subcommand by name
function M.dispatch(subcmd)
  if subcmd == "install" then
    require("esmodtree.install").run()
  elseif subcmd == "down" or subcmd == "up" then
    vim.notify("Esmodtree: '" .. subcmd .. "' is not yet implemented", vim.log.levels.ERROR)
  else
    vim.notify("Esmodtree: unknown command '" .. subcmd .. "'", vim.log.levels.ERROR)
  end
end

--- Return list of subcommands for tab completion
function M.complete()
  return SUBCOMMANDS
end

return M

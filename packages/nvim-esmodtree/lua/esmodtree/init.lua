local M = {}

local SUBCOMMANDS = { "check", "down", "updown", "up", "install" }

function M.setup(opts)
  opts = opts or {}
end

--- Dispatch a subcommand by name. Defaults to "check" when subcmd is nil.
function M.dispatch(subcmd)
  subcmd = subcmd or "check"

  if subcmd == "check" then
    require("esmodtree.check").run()
  elseif subcmd == "install" then
    require("esmodtree.install").run()
  elseif subcmd == "down" or subcmd == "updown" or subcmd == "up" then
    require("esmodtree.runner").run(subcmd)
  else
    vim.notify("Esmodtree: unknown command '" .. subcmd .. "'", vim.log.levels.ERROR)
  end
end

--- Return list of subcommands for tab completion
function M.complete()
  return SUBCOMMANDS
end

return M

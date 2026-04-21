local M = {}

local SUBCOMMANDS = { "check", "down", "updown", "up", "install" }

function M.setup(opts)
  opts = opts or {}

  -- Simple subcommand mappings
  vim.keymap.set("n", "<Plug>(esmodtree-down)", function()
    require("esmodtree.runner").run("down")
  end, { desc = "Esmodtree down" })

  vim.keymap.set("n", "<Plug>(esmodtree-up)", function()
    require("esmodtree.runner").run("up")
  end, { desc = "Esmodtree up" })

  vim.keymap.set("n", "<Plug>(esmodtree-updown)", function()
    require("esmodtree.runner").run("updown")
  end, { desc = "Esmodtree updown" })

  -- Symbol-filtered mappings (word under cursor)
  vim.keymap.set("n", "<Plug>(esmodtree-up-symbol)", function()
    local symbol = vim.fn.expand("<cword>")
    require("esmodtree.runner").run("up", symbol)
  end, { desc = "Esmodtree up for symbol under cursor" })

  vim.keymap.set("n", "<Plug>(esmodtree-updown-symbol)", function()
    local symbol = vim.fn.expand("<cword>")
    require("esmodtree.runner").run("updown", symbol)
  end, { desc = "Esmodtree updown for symbol under cursor" })
end

--- Dispatch a subcommand by name. `fargs` is a list of command-line arguments
--- (e.g. {"up", "MyButton"}). Defaults to "check" when empty/nil.
function M.dispatch(fargs)
  fargs = fargs or {}
  local subcmd = fargs[1] or "check"
  local symbol = fargs[2]

  if subcmd == "check" then
    require("esmodtree.check").run()
  elseif subcmd == "install" then
    require("esmodtree.install").run()
  elseif subcmd == "down" or subcmd == "updown" or subcmd == "up" then
    require("esmodtree.runner").run(subcmd, symbol)
  else
    vim.notify("Esmodtree: unknown command '" .. subcmd .. "'", vim.log.levels.ERROR)
  end
end

--- Return list of subcommands for tab completion
function M.complete()
  return SUBCOMMANDS
end

return M

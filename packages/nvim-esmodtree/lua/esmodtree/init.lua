local M = {}

local SUBCOMMANDS = { "check", "down", "updown", "up", "ldown", "lupdown", "lup", "install" }

--- @class esmodtree.Config
--- @field use_colors boolean Whether to colorize the float window output

--- @type esmodtree.Config
local DEFAULTS = {
  use_colors = true,
}

--- Active configuration. Populated with defaults so the plugin works
--- correctly even when `setup()` is never called.
--- @type esmodtree.Config
M.config = vim.deepcopy(DEFAULTS)

--- @param opts? esmodtree.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), opts or {})

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

  -- Location list mappings
  vim.keymap.set("n", "<Plug>(esmodtree-ldown)", function()
    require("esmodtree.runner").run("down", nil, "loclist")
  end, { desc = "Esmodtree down (loclist)" })

  vim.keymap.set("n", "<Plug>(esmodtree-lup)", function()
    require("esmodtree.runner").run("up", nil, "loclist")
  end, { desc = "Esmodtree up (loclist)" })

  vim.keymap.set("n", "<Plug>(esmodtree-lupdown)", function()
    require("esmodtree.runner").run("updown", nil, "loclist")
  end, { desc = "Esmodtree updown (loclist)" })

  vim.keymap.set("n", "<Plug>(esmodtree-lup-symbol)", function()
    local symbol = vim.fn.expand("<cword>")
    require("esmodtree.runner").run("up", symbol, "loclist")
  end, { desc = "Esmodtree up for symbol under cursor (loclist)" })

  vim.keymap.set("n", "<Plug>(esmodtree-lupdown-symbol)", function()
    local symbol = vim.fn.expand("<cword>")
    require("esmodtree.runner").run("updown", symbol, "loclist")
  end, { desc = "Esmodtree updown for symbol under cursor (loclist)" })
end

--- Dispatch a subcommand by name. `fargs` is a list of command-line arguments
--- (e.g. {"up", "MyButton"}). Defaults to "check" when empty/nil.
--- @param fargs? string[]
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
  elseif subcmd == "ldown" or subcmd == "lupdown" or subcmd == "lup" then
    local cli_subcmd = subcmd:sub(2) -- strip leading "l"
    require("esmodtree.runner").run(cli_subcmd, symbol, "loclist")
  else
    vim.notify("Esmodtree: unknown command '" .. subcmd .. "'", vim.log.levels.ERROR)
  end
end

--- Return list of subcommands for tab completion
--- @return string[]
function M.complete()
  return SUBCOMMANDS
end

return M

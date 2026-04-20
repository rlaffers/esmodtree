vim.api.nvim_create_user_command("Esmodtree", function(opts)
  local subcmd = opts.fargs[1]
  if not subcmd then
    vim.notify("Esmodtree: subcommand required (install, down, up)", vim.log.levels.ERROR)
    return
  end
  require("esmodtree").dispatch(subcmd)
end, {
  nargs = 1,
  complete = function()
    return require("esmodtree").complete()
  end,
})

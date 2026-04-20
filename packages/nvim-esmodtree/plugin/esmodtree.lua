vim.api.nvim_create_user_command("Esmodtree", function(opts)
  require("esmodtree").dispatch(opts.fargs[1])
end, {
  nargs = "?",
  complete = function()
    return require("esmodtree").complete()
  end,
})

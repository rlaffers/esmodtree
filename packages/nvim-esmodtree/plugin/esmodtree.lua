vim.api.nvim_create_user_command("Esmodtree", function(opts)
  require("esmodtree").dispatch(opts.fargs)
end, {
  nargs = "*",
  complete = function()
    return require("esmodtree").complete()
  end,
})

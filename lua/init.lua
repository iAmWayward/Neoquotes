return {
  setup = function(opts)
    require("config").setup(opts)
    require("commands").setup()
  end,
}

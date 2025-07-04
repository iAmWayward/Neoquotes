-- Only load if not already loaded
if vim.g.loaded_phrase_of_the_day then
  return
end
vim.g.loaded_phrase_of_the_day = 1

return {
  setup = function(opts)
    require("config.config").setup(opts)
    require("plugins.homemade").setup()
    require("functions.commands").setup()
  end,
}

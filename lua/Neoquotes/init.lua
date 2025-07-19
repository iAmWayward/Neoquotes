local M = {}

function M.setup(opts)
  -- if vim.g.loaded_phrase_of_the_day then
  --   return
  -- end
  vim.g.loaded_phrase_of_the_day = 1
  require("config").setup(opts)
  require("Neoquotes.commands").setup()
end

return M

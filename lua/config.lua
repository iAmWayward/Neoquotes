local M = {}

-- Default configuration
local default_config = {
  collections = { "taoist", "buddhist" },
  custom_quotes = {},
  format = {
    prefix = "💭 ",
    author_prefix = "   — ",
    add_empty_lines = true,
    attribute_author = true,
    column_limit = 120,
  },
  auto_discover = true,
}

-- Plugin configuration (populated in setup)
M.config = {}

-- Deep merge utility
local function merge(t1, t2)
  for k, v in pairs(t2) do
    if type(v) == "table" and type(t1[k] or false) == "table" then
      merge(t1[k], v)
    else
      t1[k] = v
    end
  end
  return t1
end

function M.setup(opts)
  opts = opts or {}
  M.config = merge(vim.deepcopy(default_config), opts)
  -- Optionally: do any additional setup/validation here
end

return M

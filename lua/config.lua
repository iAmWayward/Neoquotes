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
  local config = vim.deepcopy(default_config)

  if opts.collections ~= nil then
    config.collections = opts.collections
  end
  if opts.custom_quotes ~= nil then
    config.custom_quotes = opts.custom_quotes
  end
  if opts.format ~= nil then
    config.format = merge(config.format, opts.format)
  end
  if opts.auto_discover ~= nil then
    config.auto_discover = opts.auto_discover
  end

  M.config = config
end

return M

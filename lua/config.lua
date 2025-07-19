local M = {}

local default_config = {
  collections = { "tips", "science", "buddhist", "taoist" },
  custom_quotes = {},
  format = {
    prefix = "💭 ",
    author_prefix = "   — ",
    add_empty_lines = true,
    attribute_author = true,
    set_column_limit = true,
    column_limit = 120,
  },
  auto_discover = true,
}

M.config = {}

local function is_array_of_strings(t)
  if type(t) ~= "table" then return false end

  -- ensure it's a dense array with no holes
  if vim.tbl_count(t) ~= #t then return false end

  -- ensure all elements are strings
  for _, v in ipairs(t) do
    if type(v) ~= "string" then
      return false
    end
  end

  return true
end

local function safe_merge(base, override)
  if type(override) ~= "table" then return base end
  local merged = vim.deepcopy(base)
  for k, v in pairs(override) do
    if type(v) == "table" and type(merged[k]) == "table" then
      merged[k] = safe_merge(merged[k], v)
    elseif v ~= nil then
      merged[k] = v
    end
  end
  return merged
end

function M.setup(opts)
  opts = type(opts) == "table" and opts or {}

  local cfg = {
    collections = default_config.collections,
    custom_quotes = default_config.custom_quotes,
    format = vim.deepcopy(default_config.format),
    auto_discover = default_config.auto_discover,
  }

  -- collections: must be an array of strings
  if opts.collections ~= nil then
    if is_array_of_strings(opts.collections) then
      cfg.collections = opts.collections
    else
      vim.notify("[neoquotes] Invalid 'collections' provided; using default", vim.log.levels.WARN)
    end
  end

  -- custom_quotes: must be a table (array or map)
  if opts.custom_quotes ~= nil then
    if type(opts.custom_quotes) == "table" then
      cfg.custom_quotes = opts.custom_quotes
    else
      vim.notify("[neoquotes] Invalid 'custom_quotes'; using default empty list", vim.log.levels.WARN)
    end
  end

  -- format: merge recursively with defaults
  if opts.format ~= nil then
    cfg.format = safe_merge(default_config.format, opts.format)
  end

  -- auto_discover: must be boolean
  if opts.auto_discover ~= nil then
    if type(opts.auto_discover) == "boolean" then
      cfg.auto_discover = opts.auto_discover
    else
      vim.notify("[neoquotes] Invalid 'auto_discover'; using default", vim.log.levels.WARN)
    end
  end

  -- finally apply
  M.config = cfg
end

return M

local M = {}

-- Cache for loaded collections
local loaded_collections = {}

-- Cache for shuffled quotes
local shuffled_quotes_cache = {
  quotes = nil,
  config_hash = nil,
  shuffle_date = nil
}

local config = require("config")

-- Default built-in collections
local DEFAULT_COLLECTIONS = {
  "buddhist",
  "taoist",
  "philosophy",
  "science",
}

---------------------------
-- Utilities
---------------------------

-- Calculate a unique hash for config and quotes (for deterministic shuffling)
local function get_config_hash(quotes)
  local hash_parts = {}
  table.insert(hash_parts, tostring(#quotes))
  local sorted_collections = {}
  for _, collection in ipairs(config.config.collections or {}) do
    table.insert(sorted_collections, collection)
  end
  table.sort(sorted_collections)
  for _, collection in ipairs(sorted_collections) do
    table.insert(hash_parts, collection)
  end
  table.insert(hash_parts, config.config.user_collections_path or "")
  return table.concat(hash_parts, "|")
end

local function get_day_number()
  local date = os.date("*t")
  local base_year = 2000
  local year_offset = date.year - base_year
  local leap_days = 0
  for y = base_year, date.year - 1 do
    if (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0) then
      leap_days = leap_days + 1
    end
  end
  return date.yday + (year_offset * 365) + leap_days
end

-- Normalize collection tables to always have {quotes=..., format=...}
local function normalize_collection(raw)
  -- Case 1: Array of {text=...,author=...}
  if vim.tbl_islist(raw) and raw[1] and raw[1].text then
    return { quotes = raw }
  end
  -- Case 2: { format = {...}, quotes = {...} }
  if type(raw) == "table" and raw.quotes then
    return raw
  end
  -- (Optional: Error out for invalid collections)
  return nil
end

---------------------------
-- Collection loading
---------------------------

local function load_builtin_collection(collection_name)
  local cache_key = "builtin_" .. collection_name
  if loaded_collections[cache_key] then
    return loaded_collections[cache_key]
  end
  local ok, raw = pcall(require, "Neoquotes.quote-collections." .. collection_name)
  if ok and type(raw) == "table" then
    local col = normalize_collection(raw)
    loaded_collections[cache_key] = col
    return col
  end
  return nil
end

local function load_user_collection(collection_name, user_path)
  local cache_key = "user_" .. user_path .. "_" .. collection_name
  if loaded_collections[cache_key] then
    return loaded_collections[cache_key]
  end
  local file_path = user_path .. "/" .. collection_name .. ".lua"
  local file = io.open(file_path, "r")
  if not file then
    return nil
  end
  file:close()
  local ok, raw = pcall(dofile, file_path)
  if ok and type(raw) == "table" then
    local col = normalize_collection(raw)
    loaded_collections[cache_key] = col
    return col
  end
  return nil
end

local function users_active_collections(user_path)
  local collections = {}
  if not user_path then
    return collections
  end
  local files = vim.fn.glob(user_path .. "/*.lua", false, true)
  for _, file_path in ipairs(files) do
    local file_name = vim.fn.fnamemodify(file_path, ":t:r")
    table.insert(collections, file_name)
  end
  return collections
end

local function load_collection(collection_name)
  local col = load_builtin_collection(collection_name)
  if col then return col end
  if config.config.user_collections_path then
    col = load_user_collection(collection_name, config.config.user_collections_path)
    if col then return col end
  end
  return nil
end

-- Utility to extract and annotate all quotes from a collection table
local function collect_quotes_from_collection(col)
  local result = {}
  local quotes = col and col.quotes or {}
  local collection_format = col and col.format
  for _, quote in ipairs(quotes) do
    local q = vim.deepcopy(quote)
    if collection_format then
      q._collection_format = collection_format
    end
    if quote.format then
      q._per_quote_format = quote.format
    end
    table.insert(result, q)
  end
  return result
end

-- Gather all active quotes (merges all user + built-in collections)
local function get_users_quotes()
  local all_quotes = {}
  -- Collections from config
  for _, collection_name in ipairs(config.config.collections or {}) do
    local col = load_collection(collection_name)
    if col then
      for _, quote in ipairs(collect_quotes_from_collection(col)) do
        table.insert(all_quotes, quote)
      end
    end
  end
  -- All collections from user path (unless already loaded above)
  if config.config.user_collections_path then
    local user_collection_names = users_active_collections(config.config.user_collections_path)
    for _, collection_name in ipairs(user_collection_names) do
      local already_loaded = false
      for _, specified_collection in ipairs(config.config.collections or {}) do
        if specified_collection == collection_name then
          already_loaded = true
          break
        end
      end
      if not already_loaded then
        local col = load_user_collection(collection_name, config.config.user_collections_path)
        if col then
          for _, quote in ipairs(collect_quotes_from_collection(col)) do
            table.insert(all_quotes, quote)
          end
        end
      end
    end
  end
  return all_quotes
end

local function get_default_quotes()
  local all_quotes = {}
  for _, collection_name in ipairs(DEFAULT_COLLECTIONS) do
    local col = load_builtin_collection(collection_name)
    if col then
      for _, quote in ipairs(collect_quotes_from_collection(col)) do
        table.insert(all_quotes, quote)
      end
    end
  end
  return all_quotes
end

---------------------------
-- Formatting and retrieval
---------------------------

function M.format_quote(quote, custom_format)
  -- Start with global config
  local fmt = vim.deepcopy(config.config.format or {})

  -- Per-collection format override
  if quote._collection_format then
    fmt = vim.tbl_deep_extend("force", fmt, quote._collection_format)
  end

  -- Per-entry (per-quote) format override
  if quote._per_quote_format then
    fmt = vim.tbl_deep_extend("force", fmt, quote._per_quote_format)
  end

  -- If caller provided a one-time override, use that (highest precedence)
  if custom_format then
    fmt = vim.tbl_deep_extend("force", fmt, custom_format)
  end

  local lines = {}

  -- Helper to wrap text
  local function wrap_text(text, limit)
    if not limit or limit < 10 then
      return { text }
    end
    local wrapped, line = {}, ""
    for word in text:gmatch("%S+") do
      if #line + #word + 1 > limit then
        table.insert(wrapped, line)
        line = word
      else
        line = (#line > 0) and (line .. " " .. word) or word
      end
    end
    if #line > 0 then
      table.insert(wrapped, line)
    end
    return wrapped
  end

  if fmt.add_empty_lines then
    table.insert(lines, "")
  end

  -- Quote body, with prefix and wrapping
  local prefix = fmt.prefix or ""
  local column_limit = (fmt.column_limit or 80)
  local quote_lines = wrap_text(quote.text, column_limit - #prefix)
  for idx, qline in ipairs(quote_lines) do
    if idx == 1 then
      table.insert(lines, prefix .. qline)
    else
      table.insert(lines, string.rep(" ", #prefix) .. qline)
    end
  end

  -- Author line, if enabled
  if fmt.attribute_author ~= false then
    local author_prefix = fmt.author_prefix or "-- "
    table.insert(lines, author_prefix .. (quote.author or ""))
  end

  if fmt.add_empty_lines then
    table.insert(lines, "")
  end

  return lines
end

function M.QuoteOfTheDay(custom_format)
  local quote = M.get_daily_quote()
  return M.format_quote(quote, custom_format)
end

---------------------------
-- Quote selection logic
---------------------------

function M.FisherYates(t)
  local tbl = {}
  for i = 1, #t do
    tbl[i] = t[i]
  end
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

function M.get_daily_quote()
  local users_quotes = get_users_quotes()
  if #users_quotes == 0 then
    users_quotes = get_default_quotes()
  end

  if #users_quotes == 0 then
    return {
      text = "No quotes available",
      author = "Plugin",
    }
  end

  local day_number = get_day_number()
  local current_config_hash = get_config_hash(users_quotes)

  -- Reshuffle if needed
  local needs_reshuffle = (
    shuffled_quotes_cache.quotes == nil or
    shuffled_quotes_cache.config_hash ~= current_config_hash
  )

  if needs_reshuffle then
    math.randomseed(tonumber(string.sub(current_config_hash:gsub("%D", ""), 1, 8)) or day_number)
    shuffled_quotes_cache.quotes = M.FisherYates(users_quotes)
    shuffled_quotes_cache.config_hash = current_config_hash
    math.randomseed(os.time()) -- Reset for other random ops
  end

  local quote_index = (day_number % #shuffled_quotes_cache.quotes) + 1

  return shuffled_quotes_cache.quotes[quote_index]
end

function M.GetRandomQuote(collection_name)
  local quotes_to_use = {}
  if collection_name then
    local col = load_collection(collection_name)
    if col then
      quotes_to_use = collect_quotes_from_collection(col)
    end
  else
    quotes_to_use = get_users_quotes()
  end
  if #quotes_to_use == 0 then
    quotes_to_use = get_default_quotes()
  end
  if #quotes_to_use == 0 then
    return {
      text = "No quotes available",
      author = "Plugin",
    }
  end
  local random_index = math.random(1, #quotes_to_use)
  return quotes_to_use[random_index]
end

---------------------------
-- List available collections
---------------------------

function M.ListCollections()
  local collections = {}
  for _, collection_name in ipairs(DEFAULT_COLLECTIONS) do
    local col = load_builtin_collection(collection_name)
    if col then
      table.insert(collections, {
        name = collection_name,
        count = #(col.quotes or {}),
        source = "built-in"
      })
    end
  end
  if config.config.user_collections_path then
    local user_collection_names = users_active_collections(config.config.user_collections_path)
    for _, collection_name in ipairs(user_collection_names) do
      local col = load_user_collection(collection_name, config.config.user_collections_path)
      if col then
        table.insert(collections, {
          name = collection_name,
          count = #(col.quotes or {}),
          source = "user"
        })
      end
    end
  end
  return collections
end

---------------------------
-- Command registration
---------------------------

function M.setup()
  if M._commands_created then return end
  M._commands_created = true

  vim.api.nvim_create_user_command("QuoteOfTheDay", function()
    local quote = M.QuoteOfTheDay()
    for _, line in ipairs(quote) do
      print(line)
    end
  end, { desc = "Show the phrase of the day" })

  vim.api.nvim_create_user_command("QuoteRandomPhrase", function(opts)
    local collection = opts.args ~= "" and opts.args or nil
    local quote = M.GetRandomQuote(collection)
    local formatted = M.format_quote(quote)
    for _, line in ipairs(formatted) do
      print(line)
    end
  end, {
    desc = "Show a random phrase",
    nargs = "?",
    complete = function()
      local collections = M.ListCollections()
      local names = {}
      for _, collection in ipairs(collections) do
        table.insert(names, collection.name)
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command("QuoteListCollections", function()
    local collections = M.ListCollections()
    print("Available phrase collections:")
    for _, collection in ipairs(collections) do
      print(string.format("  %s (%d quotes)", collection.name, collection.count))
    end
  end, { desc = "List available phrase collections" })
end

return M

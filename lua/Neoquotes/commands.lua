local M = {}

--- Cache for loaded collections
local loaded_collections = {}

--- Cache for shuffled quotes
local shuffled_quotes_cache = {
  quotes = nil,
  config_hash = nil,
  shuffle_date = nil
}

-- Reference to plugin config
local config = require("config")

--- Table of collections available in quote-collections
local DEFAULT_COLLECTIONS = {
  "buddhist",
  "philosophy",
  "science",
  "taoist"
}

---@param t table The table of quotes to shuffle
---@return table ShuffledCollection The shuffled quotes
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

local function get_config_hash(quotes)
  local hash_parts = {}

  table.insert(hash_parts, tostring(#quotes))

  -- Sort collections for consistent hashing
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

---------------------------
-- Command registration
---------------------------

---
function M.setup()
  -- Only create commands once
  if M._commands_created then
    return
  end
  M._commands_created = true

  -- Command: PhraseOfTheDay
  vim.api.nvim_create_user_command("QuoteOfTheDay", function()
    local quote = M.QuoteOfTheDay()
    for _, line in ipairs(quote) do
      print(line)
    end
  end, {
    desc = "Show the phrase of the day",
  })

  -- Command: RandomPhrase
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

  -- Command: ListPhraseCollections
  vim.api.nvim_create_user_command("QuoteListCollections", function()
    local collections = M.ListCollections()
    print("Available quote collections:")
    for _, collection in ipairs(collections) do
      print(string.format("  %s (%d quotes)", collection.name, collection.count))
    end
  end, {
    desc = "List available quote collections",
  })
end

---------------------------
-- Formatting and retrieval
---------------------------
function M.format_quote(quote, custom_format)
  local fmt = custom_format or config.config.format

  -- Check if the quote has collection-specific formatting
  if quote._collection_format then
    -- Merge collection format with global format, collection takes precedence
    fmt = vim.tbl_deep_extend("force", fmt, quote._collection_format)
  end

  local lines = {}

  -- Helper to wrap text to col_limit
  local function wrap_text(text, limit)
    local wrapped = {}
    local line = ""
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

  -- Config opt
  if fmt.add_empty_lines then
    table.insert(lines, "")
  end

  ---
  ---@return table Quote A conditionally line-formatted table made from the
  ---                     raw quote string
  local quote_lines = function()
    if fmt.set_column_limit then
      return wrap_text(quote.text, fmt.column_limit - #fmt.prefix)
    else
      return { quote.text }
    end
  end

  for idx, qline in ipairs(quote_lines()) do
    if idx == 1 then
      table.insert(lines, fmt.prefix .. qline)
    else
      table.insert(lines, string.rep(" ", #fmt.prefix) .. qline)
    end
  end


  -- Author attribution/Second printed line
  if fmt.attribute_author and quote.author ~= nil then
    local author_line = fmt.author_prefix .. quote.author
    table.insert(lines, author_line)
  end

  -- Config opt
  if fmt.add_empty_lines then
    table.insert(lines, "")
  end

  return lines
end

function M.QuoteOfTheDay(custom_format)
  local quote = M.get_daily_quote()
  return M.format_quote(quote, custom_format)
end

-- Utility to merge user config with defaults if needed (shouldn't need this here)
-- Just use config.config

---------------------------
-- Collection handling
---------------------------

local function load_builtin_collection(collection_name)
  local cache_key = "builtin_" .. collection_name
  if loaded_collections[cache_key] then
    return loaded_collections[cache_key]
  end
  local ok, collection_data = pcall(require, "Neoquotes.quote-collections." .. collection_name)
  if ok and type(collection_data) == "table" then
    -- Process the collection data to add metadata to quotes
    local quotes = collection_data.quotes or collection_data
    local format_overrides = collection_data.format

    -- Add collection format to each quote
    if format_overrides then
      for _, quote in ipairs(quotes) do
        quote._collection_format = format_overrides
        quote._collection_name = collection_name
      end
    else
      -- Just add collection name for reference
      for _, quote in ipairs(quotes) do
        quote._collection_name = collection_name
      end
    end

    loaded_collections[cache_key] = quotes
    return quotes
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
  local ok, collection_data = pcall(dofile, file_path)
  if ok and type(collection_data) == "table" then
    -- Process the collection data to add metadata to quotes
    local quotes = collection_data.quotes or collection_data
    local format_overrides = collection_data.format

    -- Add collection format to each quote
    if format_overrides then
      for _, quote in ipairs(quotes) do
        quote._collection_format = format_overrides
        quote._collection_name = collection_name
      end
    else
      -- Just add collection name for reference
      for _, quote in ipairs(quotes) do
        quote._collection_name = collection_name
      end
    end

    loaded_collections[cache_key] = quotes
    return quotes
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
  local quotes = load_builtin_collection(collection_name)
  if quotes then
    return quotes
  end
  if config.config.user_collections_path then
    quotes = load_user_collection(collection_name, config.config.user_collections_path)
    if quotes then
      return quotes
    end
  end
  return nil
end

local function get_users_quotes()
  local all_quotes = {}
  for _, collection_name in ipairs(config.config.collections) do
    local quotes = load_collection(collection_name)
    if quotes then
      for _, quote in ipairs(quotes) do
        table.insert(all_quotes, quote)
      end
    end
  end
  if config.config.user_collections_path then
    local user_collection_names = users_active_collections(config.config.user_collections_path)
    for _, collection_name in ipairs(user_collection_names) do
      local already_loaded = false
      for _, specified_collection in ipairs(config.config.collections) do
        if specified_collection == collection_name then
          already_loaded = true
          break
        end
      end
      if not already_loaded then
        local quotes = load_user_collection(collection_name, config.config.user_collections_path)
        if quotes then
          for _, quote in ipairs(quotes) do
            table.insert(all_quotes, quote)
          end
        end
      end
    end
  end
  return all_quotes
end

local function get_default_quotes()
  local quotes = load_builtin_collection("western-philosophy")
  if quotes then
    return quotes
  end
  return {}
end

---------------------------
-- Public API
---------------------------

function M.ListCollections()
  local collections = {}
  for _, collection_name in ipairs(DEFAULT_COLLECTIONS) do
    local quotes = load_builtin_collection(collection_name)
    if quotes then
      table.insert(collections, {
        name = collection_name,
        count = #quotes,
        source = "built-in"
      })
    end
  end
  if config.config.user_collections_path then
    local user_collection_names = users_active_collections(config.config.user_collections_path)
    for _, collection_name in ipairs(user_collection_names) do
      local quotes = load_user_collection(collection_name, config.config.user_collections_path)
      if quotes then
        table.insert(collections, {
          name = collection_name,
          count = #quotes,
          source = "user"
        })
      end
    end
  end
  return collections
end

function M.GetRandomQuote(collection_name)
  local quotes_to_use = {}
  if collection_name then
    local collection_data = load_collection(collection_name)
    if collection_data then
      quotes_to_use = collection_data
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

local function get_day_number()
  local date = os.date("*t")
  -- Day calculation accounting for leap years
  local base_year = 2000 -- Use a consistent base year
  local year_offset = date.year - base_year

  -- Calculate leap days since base year
  local leap_days = 0
  for y = base_year, date.year - 1 do
    if (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0) then
      leap_days = leap_days + 1
    end
  end

  return date.yday + (year_offset * 365) + leap_days
end

--- Function which changes quotes once every 24h
--- If the quotes in the config table change, the
--- table is reshuffled.
--- @return table Pair Quote and the person attributed
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

  -- Check if we need to reshuffle (config changed or first time)
  local needs_reshuffle = (
    shuffled_quotes_cache.quotes == nil or
    shuffled_quotes_cache.config_hash ~= current_config_hash
  )

  if needs_reshuffle then
    -- Use a deterministic seed based on config hash for consistency
    -- Then shuffle the quote table using the Fisher-Yates Algorithm
    -- TODO: Implement config opt for other sorting schemes
    math.randomseed(tonumber(string.sub(current_config_hash:gsub("%D", ""), 1, 8)) or day_number)
    shuffled_quotes_cache.quotes = M.FisherYates(users_quotes)
    shuffled_quotes_cache.config_hash = current_config_hash
    math.randomseed(os.time()) -- Reset for other random operations
  end

  -- Use day_number directly for index calculation
  local quote_index = (day_number % #shuffled_quotes_cache.quotes) + 1

  return shuffled_quotes_cache.quotes[quote_index]
end

return M

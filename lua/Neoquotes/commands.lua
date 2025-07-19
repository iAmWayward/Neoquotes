local M = {}

--- Cache for loaded collections
local loaded_collections = {}

-- Reference to plugin config
local config = require("config")

local DEFAULT_COLLECTIONS = {
  "buddhist",
  "stoic",
  "inspirational",
  "western-philosophy",
  "science",
  "humor"
}

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
  vim.api.nvim_create_user_command("PhraseOfTheDay", function()
    local quote = M.QuoteOfTheDay()
    for _, line in ipairs(quote) do
      print(line)
    end
  end, {
    desc = "Show the phrase of the day",
  })

  -- Command: RandomPhrase
  vim.api.nvim_create_user_command("RandomPhrase", function(opts)
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
  vim.api.nvim_create_user_command("ListPhraseCollections", function()
    local collections = M.ListCollections()
    print("Available phrase collections:")
    for _, collection in ipairs(collections) do
      print(string.format("  %s (%d quotes)", collection.name, collection.count))
    end
  end, {
    desc = "List available phrase collections",
  })
end

---------------------------
-- Formatting and retrieval
---------------------------
function M.format_quote(quote, custom_format)
  local fmt = custom_format or config.config.format
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

  if fmt.add_empty_lines then
    table.insert(lines, "")
  end

  local quote_lines = wrap_text(quote.text, fmt.column_limit - #fmt.prefix)
  for idx, qline in ipairs(quote_lines) do
    if idx == 1 then
      table.insert(lines, fmt.prefix .. qline)
    else
      table.insert(lines, string.rep(" ", #fmt.prefix) .. qline)
    end
  end

  if fmt.attribute_author then
    local author_line = fmt.author_prefix .. quote.author
    table.insert(lines, author_line)
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

-- Utility to merge user config with defaults if needed (shouldn’t need this here)
-- Just use config.config

---------------------------
-- Collection handling
---------------------------

local function load_builtin_collection(collection_name)
  local cache_key = "builtin_" .. collection_name
  if loaded_collections[cache_key] then
    return loaded_collections[cache_key]
  end
  local ok, quotes = pcall(require, "Neoquotes.quote-collections." .. collection_name)
  if ok and type(quotes) == "table" then
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
  local ok, quotes = pcall(dofile, file_path)
  if ok and type(quotes) == "table" then
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

  -- Use Fisher-Yates shuffle with day-based seed for consistent daily quotes
  local date = os.date("*t")
  local day_of_year = date.yday + (date.year * 365)

  math.randomseed(day_of_year)
  local shuffled_quotes = M.FisherYates(users_quotes)

  -- Reset seed for other random operations
  -- TODO: More sorting algos?
  math.randomseed(os.time())

  -- Return the first quote from the shuffled array
  return shuffled_quotes[1]
end

return M

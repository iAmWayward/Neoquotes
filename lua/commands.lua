local M = {}

-- Cache for loaded collections
local loaded_collections = {}
local config = {}

local DEFAULT_COLLECTIONS = {
  "buddhist",
  "stoic",
  "inspirational",
  "western-philosophy",
  "science",
  "humor"
}

-- plugin/phrase-of-the-day.lua
-- User commands and keymaps


-- Create user commands
vim.api.nvim_create_user_command("PhraseOfTheDay", function()
  local phrase = require("phrase-of-the-day")
  local quote = phrase.get_formatted_daily_quote()

  -- Display in a floating window or print to command line
  for _, line in ipairs(quote) do
    print(line)
  end
end, {
  desc = "Show the phrase of the day",
})

vim.api.nvim_create_user_command("RandomPhrase", function(opts)
  local phrase = require("phrase-of-the-day")
  local collection = opts.args ~= "" and opts.args or nil
  local quote = phrase.get_random_quote(collection)
  local formatted = phrase.format_quote(quote)

  for _, line in ipairs(formatted) do
    print(line)
  end
end, {
  desc = "Show a random phrase",
  nargs = "?",
  complete = function()
    local phrase = require("phrase-of-the-day")
    local collections = phrase.list_collections()
    local names = {}
    for _, collection in ipairs(collections) do
      table.insert(names, collection.name)
    end
    return names
  end,
})

vim.api.nvim_create_user_command("ListPhraseCollections", function()
  local phrase = require("phrase-of-the-day")
  local collections = phrase.list_collections()

  print("Available phrase collections:")
  for _, collection in ipairs(collections) do
    print(string.format("  %s (%d quotes)", collection.name, collection.count))
  end
end, {
  desc = "List available phrase collections",
})


-- Format quote for display
function M.format_quote(quote, custom_format)
  local fmt = custom_format or config.format
  local lines = {}

  if fmt.add_empty_lines then
    table.insert(lines, "")
  end

  table.insert(lines, fmt.prefix .. quote.text)
  table.insert(lines, fmt.author_prefix .. quote.author)

  if fmt.add_empty_lines then
    table.insert(lines, "")
  end

  return lines
end

-- Get formatted daily quote
function M.get_formatted_daily_quote(custom_format)
  local quote = M.get_daily_quote()
  return M.format_quote(quote, custom_format)
end

---TODO: Evaluate
--- Merge user config with defaults
---@param opts table User configuration options
local function merge_config(opts)
  config = vim.tbl_deep_extend("force", {
    collections = DEFAULT_COLLECTIONS, -- Default collections to load
    user_collections_path = nil,       -- Path to user's custom collections
    format = {
      prefix = "💭 ",
      author_prefix = "   — ",
      add_empty_lines = true,
    },
  }, opts or {})
end

--- Load a collection from the plugin's built-in collections
---@param collection_name string Name of the collection file (without .lua)
---@return table|nil quotes Collection of quotes or nil if not found
local function load_builtin_collection(collection_name)
  local cache_key = "builtin_" .. collection_name

  if loaded_collections[cache_key] then
    return loaded_collections[cache_key]
  end

  local ok, quotes = pcall(require, "phrase-of-the-day.quote-collections." .. collection_name)
  if ok and type(quotes) == "table" then
    loaded_collections[cache_key] = quotes
    return quotes
  end

  return nil
end

--- Load a collection from user's custom path
---@param collection_name string Name of the collection file (without .lua)
---@param user_path string Path to user's collections directory
---@return table|nil quotes Collection of quotes or nil if not found
local function load_user_collection(collection_name, user_path)
  local cache_key = "user_" .. user_path .. "_" .. collection_name

  if loaded_collections[cache_key] then
    return loaded_collections[cache_key]
  end

  local file_path = user_path .. "/" .. collection_name .. ".lua"

  -- Check if file exists
  local file = io.open(file_path, "r")
  if not file then
    return nil
  end
  file:close()

  -- Load the file
  local ok, quotes = pcall(dofile, file_path)
  if ok and type(quotes) == "table" then
    loaded_collections[cache_key] = quotes
    return quotes
  end

  return nil
end

--- Get all available collections from user's custom path
---@param user_path string Path to user's collections directory
---@return table collections List of collection names found in the directory
local function get_user_collection_names(user_path)
  local collections = {}

  if not user_path then
    return collections
  end

  -- Use vim.fn.glob to find all .lua files in the directory
  local files = vim.fn.glob(user_path .. "/*.lua", false, true)

  for _, file_path in ipairs(files) do
    local file_name = vim.fn.fnamemodify(file_path, ":t:r") -- Get filename without extension
    table.insert(collections, file_name)
  end

  return collections
end


--- Load a specific collection by name
---@param collection_name string Name of the collection to load
---@return table|nil quotes Collection of quotes or nil if not found
local function load_collection(collection_name)
  -- First try to load from built-in collections
  local quotes = load_builtin_collection(collection_name)
  if quotes then
    return quotes
  end

  -- Then try user's custom collections if path is configured
  if config.user_collections_path then
    quotes = load_user_collection(collection_name, config.user_collections_path)
    if quotes then
      return quotes
    end
  end

  return nil
end

--- Get all quotes from user's specified collections
---@return table quotes Combined quotes from all specified collections
local function get_users_quotes()
  local all_quotes = {}

  -- Load from specified collections
  for _, collection_name in ipairs(config.collections) do
    local quotes = load_collection(collection_name)
    if quotes then
      for _, quote in ipairs(quotes) do
        table.insert(all_quotes, quote)
      end
    end
  end

  -- If user has a custom path, load all collections from there as well
  if config.user_collections_path then
    local user_collection_names = get_user_collection_names(config.user_collections_path)
    for _, collection_name in ipairs(user_collection_names) do
      -- Only load if not already in the specified collections
      local already_loaded = false
      for _, specified_collection in ipairs(config.collections) do
        if specified_collection == collection_name then
          already_loaded = true
          break
        end
      end

      if not already_loaded then
        local quotes = load_user_collection(collection_name, config.user_collections_path)
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

--- Get default quotes (fallback when no collections are available)
---@return table quotes Default set of quotes
local function get_default_quotes()
  -- Try to load from a default collection, fallback to hardcoded quotes
  local quotes = load_builtin_collection("inspirational")
  if quotes then
    return quotes
  end

  -- Setup function for the plugin
  function M.setup(opts)
    merge_config(opts)
  end

  return {}
end


--- List all available collections
---@return table collections List of collection info with name and count
function M.list_collections()
  local collections = {}

  -- Add built-in collections
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

  -- Add user collections
  if config.user_collections_path then
    local user_collection_names = get_user_collection_names(config.user_collections_path)
    for _, collection_name in ipairs(user_collection_names) do
      local quotes = load_user_collection(collection_name, config.user_collections_path)
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

--- Get a random quote from specified collection or all available
---@param collection_name string|nil Name of specific collection, nil for all
---@return table quote Random quote with text and author
function M.get_random_quote(collection_name)
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

--- Get daily quote (deterministic based on date)
---@return table quote Quote with text and author
function M.get_daily_quote()
  local users_quotes = get_users_quotes()
  if #users_quotes == 0 then
    users_quotes = get_default_quotes()
  end

  -- Get current date as a number for seeding
  local date = os.date("*t")
  local day_of_year = date.yday + (date.year * 365)

  -- Use day-based index (deterministic for the day)
  local quote_index = (day_of_year % #users_quotes) + 1
  return users_quotes[quote_index]
end

return M

-- Get the plugin path

local M = {}

-- Cache for loaded collections
local loaded_collections = {}

local function get_plugin_path()
	local info = debug.getinfo(1, "S")
	local plugin_path = info.source:match("@(.*/)")
	return plugin_path
end

-- Load a single collection file
local function load_collection(collection_name)
	if loaded_collections[collection_name] then
		return loaded_collections[collection_name]
	end

	local success, collection = pcall(require, "phrase-of-the-day.collections." .. collection_name)
	if success and type(collection) == "table" then
		loaded_collections[collection_name] = collection
		return collection
	end

	return nil
end

-- Auto-discover available collections
local function discover_collections()
	if not config.auto_discover then
		return {}
	end

	local plugin_path = get_plugin_path()
	local collections_path = plugin_path .. "collections"

	local collection_files = vim.fs.find(function(name, path)
		return name:match("%.lua$") and not name:match("^%.") -- .lua files, not hidden
	end, {
		path = collections_path,
		type = "file",
		limit = math.huge,
	})

	local available_collections = {}
	for _, file_path in ipairs(collection_files) do
		local filename = vim.fs.basename(file_path)
		local collection_name = filename:match("^(.+)%.lua$")
		if collection_name then
			table.insert(available_collections, collection_name)
		end
	end

	return available_collections
end

-- Merge user config with defaults
local function merge_config(user_config)
	config = vim.tbl_deep_extend("force", default_config, user_config or {})

	-- If auto-discover is enabled, merge discovered collections with specified ones
	if config.auto_discover then
		local discovered = discover_collections()
		local all_collections = vim.tbl_extend("force", {}, config.collections)

		-- Add discovered collections that aren't already specified
		for _, collection_name in ipairs(discovered) do
			if not vim.tbl_contains(config.collections, collection_name) then
				table.insert(all_collections, collection_name)
			end
		end

		config.collections = all_collections
	end
end

-- Get all available quotes based on configuration
local function get_available_quotes()
	local available_quotes = {}

	-- Add quotes from specified collections
	for _, collection_name in ipairs(config.collections) do
		local collection = load_collection(collection_name)
		if collection then
			for _, quote in ipairs(collection) do
				-- Validate quote structure
				if type(quote) == "table" and quote.text and quote.author then
					table.insert(available_quotes, quote)
				end
			end
		end
	end

	-- Add custom quotes
	for _, quote in ipairs(config.custom_quotes) do
		if type(quote) == "table" and quote.text and quote.author then
			table.insert(available_quotes, quote)
		end
	end

	return available_quotes
end

-- Get a random quote from specified collection or all available
function M.get_random_quote(collection)
	local quotes_to_use = {}

	if collection then
		local collection_data = load_collection(collection)
		if collection_data then
			quotes_to_use = collection_data
		end
	else
		quotes_to_use = get_available_quotes()
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

-- Get daily quote (deterministic based on date)
function M.get_daily_quote()
	local available_quotes = get_available_quotes()

	if #available_quotes == 0 then
		return {
			text = "No quotes available",
			author = "Plugin",
		}
	end

	-- Get current date as a number for seeding
	local date = os.date("*t")
	local day_of_year = date.yday + (date.year * 365)

	-- Use day-based index (deterministic for the day)
	local quote_index = (day_of_year % #available_quotes) + 1
	return available_quotes[quote_index]
end

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

-- Setup function for the plugin
function M.setup(opts)
	merge_config(opts)
end

return M

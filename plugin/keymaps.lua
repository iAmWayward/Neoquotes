-- plugin/phrase-of-the-day.lua
-- User commands and keymaps

-- Only load if not already loaded
if vim.g.loaded_phrase_of_the_day then
	return
end
vim.g.loaded_phrase_of_the_day = 1

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

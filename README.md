# Neoquotes
Neoquotes is a random quote/quote-of-the-day plugin for the [Neovim](https://github.com/neovim/neovim) text editor. 

<img width="1145" height="537" alt="coffeeTheorems" src="https://github.com/user-attachments/assets/9d6ea4dc-39fc-4800-a49a-cb4a61861672" />

## Why neoquotes?
The project started as a simple lua function in my dashboard.nvim config to display a quote every day from a table of quotes. Then I added a command to generate a one-off random quote. 

That was pretty nice, and as I added more functionality, I decided that it was extensive enough to justify tightening it up and releasing it as a plugin. 

### This functionality includes:
* Preconfigured quote collections such as "philosophy" "science" and "minecract"
* The ability to quickly and conveniently add your own quote collection(s)
* The ability to configure a prefix for both the quote and the author
* The ability to hide author attribution 
    * Wow I should add hiding the quote
* Fisher-Yates shuffle algorithm shamelessly liberated from this [gist](https://gist.github.com/Uradamus/10323382)
* Optional column limit formatting (for use in buffers that do not wrap such as dashboard.nvim)
* Optional vertical padding
* Handles leap-years lol
* Only re-shuffle when the table of quotes is changed, not on arbitrary config changes.

So it's a little over-engineered. But it is very fit for purpose.
<img width="327" height="33" alt="loadTime" src="https://github.com/user-attachments/assets/b581f54c-64f8-4ca5-99eb-3f3124772ff6" />

## Minimal lazy.nvim config
```lua
return {
  {
    "iAmWayward/quotes.nvim",
    event = "VeryLazy",
    opts = {},
  }
}
```

## Example Use
[Dashboard.nvim](https://github.com/nvimdev/dashboard-nvim)
```lua
{  
    'nvimdev/dashboard-nvim',
    config = function()
        require("dashboard").setup({
          config = {
                -- ... [your dashboard setup]
                -- Use QuoteOfTheDay command to get today's quote
                footer = require("quotes.functions.commands").QuoteOfTheDay(),
            }, 
        })
    end
},
```

## Default Config
```lua
return {
  "iAmWayward/quotes.nvim",
  opts = {
    -- Specify which built-in collections to include
    -- Setting this will override defaults
    collections = {
    -- The collections not-included in the default set are commented out here
      "tips", -- neovim motion tips
      "swe",  -- Software Engineering
      "buddhist",
      "taoist",
      "science", 
      -- "generic-inspiration",
      -- "western-philosophy"
      -- "minecraft", -- minecraft title screen splashes
    },
    
    -- Path to user's custom quote collections
    -- Each .lua file in this directory will be loaded as a collection
    -- This also overrides defaults, but cooperates with manual selections
    user_collections_path = vim.fn.expand("~/my-quotes"), 
    
    -- Formatting options
    format = {
      prefix = "💭 ", -- Prefix for the quote
      author_prefix = "   — ", -- Prefix for the author quote
      add_empty_lines = true, -- pad the quote with blank lines
      attribute_author = true,
      set_column_limit = true,
      column_limit = 120,
    },
  },
}
```


## Adding your own quotes
The format for a quote table is pretty simple:

```lua
return {
    {
        text = "The mind is everything. What you think you become.",
        author = "Buddha",
    },
    {
        text = "Peace comes from within. Do not seek it without.",
        author = "Buddha",
    },
    -- etc...
}
```

## Commands
| Command               | Description                              |
|-----------------------|------------------------------------------|
| `:QuoteOfTheDay`      | This only changes once every 24 hours    |
| `:QuoteRandomPhrase`  | See a random phrase (not just your QOTD) |
| `:QuoteListCollections` | Show which collections you have enabled |





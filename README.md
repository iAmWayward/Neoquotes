# NeoQuotes
Neoquotes is a simple plugin for the [Neovim](https://github.com/neovim/neovim)
text editor. It can be used to give a "Quote of the Day"
based on the current date, and/or return a random quote
from a given set of quotes.

Quotes are defined in lua tables. Neoquotes comes with a few of its
default quote collections enabled. A wider set of more niche quotes
is also available, but these quotes must be enabled in the config.

## Minimal config
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
      "buddhist",
      "taoist",
      "generic-inspiration",
      "stem",
      -- "western-philosophy"
      -- "minecraft", 
      -- "sims",
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
    },
    -- TODO:
    -- algorithm = weight_smaller_collections -- true_random
  },
}
```

You can also use `:PhraseOfTheDay`

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

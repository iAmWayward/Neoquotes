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
    "iAmWayward/Neoquotes",
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
                footer = require("Neoquotes.commands").QuoteOfTheDay(),
            }, 
        })
    end
},
```

# Setup
## Default Config
```lua
return {
  "iAmWayward/Neoquotes",
  opts = {
    -- Specify which built-in collections to include
    -- Setting this will override defaults
    collections = {
    -- The collections not-included in the default set are commented out here
      "tips", -- neovim motion tips
      "buddhist",
      "taoist",
      -- "science", 
      -- "philosophy"
      -- "minecraft", -- minecraft title screen splashes
      -- "sims", -- Sims loading screen splashes
    },
    
    -- Path to your custom quote collections
    -- Each .lua file in this directory will be loaded as a collection
    -- This also overrides defaults, but cooperates with manual selections
    user_collections_path = vim.fn.expand("~/my-quotes"), -- IE put quotes in .config/nvim/my-quotes/my-quote-file.lua

    custom_quotes = {}, -- One-off quotes  
    -- Formatting options
    format = {
      prefix = "💭 ",          -- Prefix for the quote
      author_prefix = "   — ", -- Prefix for the author quote
      add_empty_lines = true,  -- pad the quote with blank lines
      attribute_author = true, -- Hide the author if you want
      set_column_limit = true, -- For environments which don't wrap like dashboard.nvim
      column_limit = 120,      -- If it's enabled
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

You can put one-off quotes directly in the plugin config

### Adding singleton quotes
```lua
opts = {
    custom_quotes = {
        { text = "Stay hungry. Stay foolish.", author = "Steve Jobs" },
        { text = "Code is like humor. When you have to explain it, it’s bad.", author = "Cory House" },
  }
}
```

### Override prefixes defined in opts for an entire collection
```lua
-- vim_shortcuts.lua
return {
  format = {
    prefix = "⌨️ ",
    author_prefix = "Usage: ",
  },
  quotes = {
    { text = "gg", author = "Move to the first line of the file" },
    { text = "G", author = "Move to the last line" },
  }
}
```

### Override prefixes on a per-quote basis
Take note that you can mix these approaches as-needed

```
-- editor_tips.lua
return {
  format = {
    prefix = "💡 ",
    author_prefix = "Tip: ",
  },
  quotes = {
    {
      text = ":%s/foo/bar/g",
      author = "Replace 'foo' with 'bar'",
    },
    { -- We give this one a special prefix which isn't shared with other members of the collection
      text = "u",
      author = "Undo",
      format = {
        prefix = "⏪ ",
        author_prefix = "Shortcut: ",
      },
    }
}
```

You can mix collections with different formats into the same config as long as each collection has valid syntax.

## Commands
| Command               | Description                              |
|-----------------------|------------------------------------------|
| `:QuoteOfTheDay`      | This only changes once every 24 hours    |
| `:QuoteRandomPhrase`  | See a random phrase (not just your QOTD) |
| `:QuoteListCollections` | Show which collections you have enabled |
| :QuoteCollectionsReload | Use this when you add new files to your custom path |



## Quickly gather quotes from formatted sources
You may find that you want to grab a bunch of quotes off a webpage that are formatted by html.
In that case, you may find this useful on your journey

```bash
curl -s 'URL' | \ # Url of the page you want to scrape
htmlq 'td li' --text | \ # See below
sed 's/"/\\"/g' | \ # Escape quotes for lua
awk 'BEGIN { print "return {" } { print "  { text = \"" $0 "\", author = nil }," } END { print "}" }'

```

`htmlq 'td li' --text` is the syntax to pull the text out of content formatted like this

```html
<table><tbody><tr>
<td width="50%" align="left" valign="top" style="border:none;">
<ul><li>Extruding Mesh Terrain</li>
<li>Balancing Domestic Coefficients</li>
<li>Inverting Career Ladder</li>
<li>Calculating Money Supply</li>
<li>Normalizing Social Network</li></ul>
</td>
<td width="50%" align="left" valign="top" style="border:none;">
<ul><li><a href="/wiki/Reticulating_Splines" class="mw-redirect" title="Reticulating Splines">Reticulating Splines</a></li>
<li>Adjusting Emotional Weights</li>
<li>Calibrating Personality Matrix</li>
<li>Inserting Chaos Generator</li></ul>
</td></tr></tbody></table>
```

Want to give it a try? Test the commands out on the Sims wiki page for [loading splash messages](https://sims.fandom.com/wiki/Loading_screen_messages)

local M = {}

-- Default configuration
local default_config = {
  -- Which quote collections to include (will auto-discover from collections/ folder)
  collections = { "taoist", "buddhist" },
  -- Custom quotes can be added here
  custom_quotes = {},
  -- Format options
  format = {
    prefix = "💭 ",
    author_prefix = "   — ",
    add_empty_lines = true,
  },
  -- Auto-discover collections from collections/ folder
  auto_discover = true,
}

-- Plugin configuration (will be set by setup)
local config = {}

-- Cache for loaded collections
local loaded_collections = {}

do return M end

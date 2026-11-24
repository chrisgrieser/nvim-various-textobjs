local M = {}
--------------------------------------------------------------------------------
---@class VariousTextobjs.Config
local defaultConfig = {
	keymaps = {
		-- See overview table in README for the defaults. (Note that lazy-loading
		-- this plugin, the default keymaps cannot be set up. If you set this to
		-- `true`, you thus need to add `lazy = false` to your lazy.nvim config.)
		useDefaults = false,

		-- disable only some default keymaps, for example { "ai", "!" }
		-- (only relevant when you set `useDefaults = true`)
		---@type string[]
		disabledDefaults = {},
	},

	forwardLooking = {
		-- Number of lines to seek forwards for a text object. See the overview
		-- table in the README for which text object uses which value.
		small = 5,
		big = 15,
	},
	behavior = {
		-- save position in jumplist when using text objects
		jumplist = true,

		-- default direction text objects seek in for the next object. Can be
		-- overridden per call by passing the direction to a textobj directly,
		-- e.g. `require("various-textobjs").url("nearest")`.
		-- * "forward": only seek ahead of the cursor (default, original behavior)
		-- * "backward": only seek behind the cursor
		-- * "nearest": seek in both directions and select the object that is
		--   closer to the cursor: fewer lines away wins (empty lines count
		--   too), ties are decided by #chars. Objects that enclose the cursor
		--   always take precedence. The `forwardLooking` seek window only
		--   bounds how far is searched (in both directions), never which of
		--   the two candidates is picked.
		---@type "forward"|"backward"|"nearest"
		searchDirection = "forward",
	},

	-- extra configuration for specific text objects
	textobjs = {
		indentation = {
			-- `false`: only indentation decreases delimit the text object
			-- `true`: indentation decreases as well as blank lines serve as delimiter
			blanksAreDelimiter = false,
		},
		subword = {
			-- When deleting the start of a camelCased word, the result should
			-- still be camelCased and not PascalCased (see #113).
			noCamelToPascalCase = true,
		},
		diagnostic = {
			wrap = true,
		},
		url = {
			patterns = { [[%l%l%l+://[^%s)%]}"'`>]+]] },
		},
	},

	notify = {
		icon = "󰠱", -- only used with notification plugins like `nvim-notify`
		whenObjectNotFound = true,
	},

	debug = false, -- debugging messages when using some text objects
}
M.config = defaultConfig

--------------------------------------------------------------------------------

---@param userConfig? VariousTextobjs.Config
function M.setup(userConfig)
	M.config = vim.tbl_deep_extend("force", M.config, userConfig or {})

	if M.config.keymaps.useDefaults then
		require("various-textobjs.config.default-keymaps").setup(M.config.keymaps.disabledDefaults)
	end
end

--------------------------------------------------------------------------------
return M

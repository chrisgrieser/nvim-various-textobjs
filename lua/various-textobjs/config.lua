local M = {}
--------------------------------------------------------------------------------
---@class VariousTextobjs.Config
local defaultConfig = {
	keymaps = {
		-- See overview table in README for the defaults. (Note that lazy-loading
		-- this plugin, the default keymaps cannot be set up. if you set this to
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
			patterns = {
				[[%l%l%l+://[^%s)%]}"'`]+]], -- exclude ) for md, "'` for strings, } for bibtex
			},
		},
	},

	notify = {
		icon = "󰠱", -- only used with notification plugins like `nvim-notify`
		whenObjectNotFound = true,
	},

	-- show debugging messages on use of certain text objects
	debug = false,
}
M.config = defaultConfig

--------------------------------------------------------------------------------

---@param userConfig? VariousTextobjs.Config
function M.setup(userConfig)
	local warn = require("various-textobjs.utils").warn

	M.config = vim.tbl_deep_extend("force", M.config, userConfig or {})

	-- DEPRECATION (2024-12-03)
	---@diagnostic disable: undefined-field
	if M.config.lookForwardSmall then
		warn("The `lookForwardSmall` option is deprecated. Use `forwardLooking.small` instead.")
	end
	if M.config.lookForwardBig then
		warn("The `lookForwardBig` option is deprecated. Use `forwardLooking.big` instead.")
	end
	if M.config.lookForwardBig then
		warn("The `lookForwardBig` option is deprecated. Use `forwardLooking.big` instead.")
	end
	if M.config.notificationIcon then
		warn("The `notificationIcon` option is deprecated. Use `notify.icon` instead.")
	end
	if M.config.notifyNotFound ~= nil then -- not nil, since `false` is a valid value
		warn("The `notifyNotFound` option is deprecated. Use `notify.whenObjectNotFound` instead.")
	end
	-- DEPRECATION (2024-12-06)
	if M.config.useDefaultKeymaps ~= nil then
		warn("The `useDefaultKeymaps` option is deprecated. Use `keymaps.useDefaults` instead.")
		M.config.keymaps.useDefaults = M.config.useDefaultKeymaps
	end
	if M.config.disabledKeymaps then
		warn("The `disabledKeymaps` option is deprecated. Use `keymaps.disabledDefaults` instead.")
		M.config.keymaps.disabledDefaults = M.config.disabledKeymaps
	end
	---@diagnostic enable: undefined-field

	if M.config.keymaps.useDefaults then
		require("various-textobjs.default-keymaps").setup(M.config.keymaps.disabledDefaults)
	end
end

--------------------------------------------------------------------------------
return M

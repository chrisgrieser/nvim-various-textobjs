local M = {}
--------------------------------------------------------------------------------
---@class VariousTextobjs.Config
local defaultConfig = {
	-- See overview table in README for the defaults keymaps.
	-- (Note that lazy-loading this plugin, the default keymaps cannot be set up.
	-- if you set this to `true`, you thus need to add `lazy = false` to your
	-- lazy.nvim config.)
	useDefaultKeymaps = false,

	---@type string[]
	disabledKeymaps = {}, -- disable only some default keymaps, e.g. { "ai", "ii" }

	-- Number of lines to seek forwards for a text object. See the overview table
	-- in the README for which text object uses which value.
	forwardLooking = {
		small = 5,
		big = 15,
	},

	notify = {
		icon = "󰠱", -- only used with notification plugins like `nvim-notify`
		whenObjectNotFound = true,
	},

	textobjs = {
		diagnostic = {
			wrap = true,
		},
		subword = {
			-- When deleting the start of a camelCased word, the result should
			-- still be camelCased and not PascalCased (see #113).
			noCamelToPascalCase = true,
		},
	},
}
M.config = defaultConfig

--------------------------------------------------------------------------------

local setupHasAlreadyBeenCalled = false

---@param userConfig? VariousTextobjs.Config
function M.setup(userConfig)
	local warn = require("various-textobjs.utils").warn
	if setupHasAlreadyBeenCalled then
		warn("`.setup()` can only be called once")
		return
	end
	setupHasAlreadyBeenCalled = true

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
		warn("The `notificationIcon` option is deprecated. Use `config.notify.icon` instead.")
	end
	if M.config.notifyNotFound then
		warn(
			"The `notifyNotFound` option is deprecated. Use `config.notify.whenObjectNotFound` instead."
		)
	end
	---@diagnostic enable: undefined-field

	if M.config.useDefaultKeymaps then
		require("various-textobjs.default-keymaps").setup(M.config.disabledKeymaps)
	end
end

--------------------------------------------------------------------------------
return M

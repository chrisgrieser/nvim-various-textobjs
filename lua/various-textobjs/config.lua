local M = {}
--------------------------------------------------------------------------------
---@class VariousTextobjs.Config
local defaultConfig = {
	-- use suggested keymaps (see overview table in README)
	useDefaultKeymaps = false,

	-- disable only some default keymaps, e.g. { "ai", "ii" }
	---@type string[]
	disabledKeymaps = {},

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
}
M.config = defaultConfig

--------------------------------------------------------------------------------

---optional setup function
---@param userConfig? VariousTextobjs.Config
function M.setup(userConfig)
	M.config = vim.tbl_deep_extend("force", M.config, userConfig or {})
	local notify = require("various-textobjs.utils").notify

	-- DEPRECATION (2024-12-03)
	---@diagnostic disable: undefined-field
	if M.config.lookForwardSmall then
		notify("The `lookForwardSmall` option is deprecated. Use `forwardLooking.small` instead.")
	end
	if M.config.lookForwardBig then
		notify("The `lookForwardBig` option is deprecated. Use `forwardLooking.big` instead.")
	end
	if M.config.lookForwardBig then
		notify("The `lookForwardBig` option is deprecated. Use `forwardLooking.big` instead.")
	end
	if M.config.notificationIcon then
		notify("The `notificationIcon` option is deprecated. Use `config.notify.icon` instead.")
	end
	if M.config.notifyNotFound then
		notify(
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

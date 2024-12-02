local M = {}
--------------------------------------------------------------------------------
---@class VariousTextobjs.Config
local defaultConfig = {
	-- set to 0 to only look in the current line
	lookForwardSmall = 5,
	lookForwardBig = 15,

	-- use suggested keymaps (see overview table in README)
	useDefaultKeymaps = false,

	-- disable only some default keymaps, e.g. { "ai", "ii" }
	---@type string[]
	disabledKeymaps = {},

	-- display notification if a text object is not found
	notifyNotFound = true,

	-- only relevant when using notification plugins like `nvim-notify`
	notificationIcon = "󰠱"
}
M.config = defaultConfig

--------------------------------------------------------------------------------

---optional setup function
---@param userConfig? VariousTextobjs.Config
function M.setup(userConfig)
	M.config = vim.tbl_deep_extend("force", M.config, userConfig or {})

	if M.config.useDefaultKeymaps then
		require("various-textobjs.default-keymaps").setup(M.config.disabledKeymaps)
	end
end

--------------------------------------------------------------------------------
return M

local M = {}
--------------------------------------------------------------------------------
---@class config
---@field lookForwardSmall? number
---@field lookForwardBig? number
---@field useDefaultKeymaps? boolean
---@field disabledKeymaps? string[]

---@type config
local defaultConfig = {
	lookForwardSmall = 5,
	lookForwardBig = 15,
	useDefaultKeymaps = false,
	disabledKeymaps = {},
}
M.config = defaultConfig

---optional setup function
---@param userConfig? config
function M.setup(userConfig)
	M.config = vim.tbl_deep_extend("force", M.config, userConfig or {})

	if M.config.useDefaultKeymaps then
		require("various-textobjs.default-keymaps").setup(M.config.disabledKeymaps)
	end
	return M.config
end

--------------------------------------------------------------------------------
return M

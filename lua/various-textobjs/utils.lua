local M = {}
--------------------------------------------------------------------------------

---runs `:normal` with bang
---@param cmdStr string
function M.normal(cmdStr)
	local is08orHigher = vim.version().major > 0 or vim.version().minor > 7
	if is08orHigher then
		vim.cmd.normal { cmdStr, bang = true }
	else
		vim.cmd("normal! " .. cmdStr)
	end
end

---equivalent to fn.getline(), but using more efficient nvim api
---@param lnum integer
---@return string
---@nodiscard
function M.getline(lnum) return vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1] end

---@param msg string
function M.warn(msg)
	local icon = require("various-textobjs.config").config.notify.icon
	vim.notify(msg, vim.log.levels.WARN, { title = "various-textobjs", icon = icon })
end

---notification when no textobj could be found
---@param msg integer|string lines tried to look forward, or custom message
function M.notFoundMsg(msg)
	if not require("various-textobjs.config").config.notify.whenObjectNotFound then return end
	local notifyText
	if type(msg) == "number" then
		local lookForwLines = msg
		notifyText = ("Textobject not found within the next %d lines."):format(lookForwLines)
		if lookForwLines == 1 then notifyText = notifyText:gsub("s%.$", ".") end
		if lookForwLines == 0 then notifyText = "Textobject not found within the line." end
	elseif type(msg) == "string" then
		notifyText = msg
	end
	local icon = require("various-textobjs.config").config.notify.icon
	vim.notify(notifyText, vim.log.levels.INFO, { title = "various-textobjs", icon = icon })
end

function M.saveJumpToJumplist()
	local jumplist = require("various-textobjs.config").config.behavior.jumplist
	if jumplist then M.normal("m`") end
end

--------------------------------------------------------------------------------
return M

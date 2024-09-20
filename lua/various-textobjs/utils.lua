local M = {}
--------------------------------------------------------------------------------

---runs :normal natively with bang
---@param cmdStr any
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
function M.getline(lnum) return vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1] end

---send notification
---@param msg string
---@param level? "info"|"trace"|"debug"|"warn"|"error"|"notfound"
function M.notify(msg, level)
	if not level then level = "info" end
	if level == "notfound" then
		if not require("various-textobjs.config").config.notifyNotFound then return end
		level = "warn"
	end
	vim.notify(msg, vim.log.levels[level:upper()], { title = "nvim-various-textobjs" })
end

---notification when no textobj could be found
---@param lookForwL integer number of lines the plugin tried to look forward
function M.notFoundMsg(lookForwL)
	local msg = ("Textobject not found within the next %d lines."):format(lookForwL)
	if lookForwL == 1 then msg = msg:gsub("s%.$", ".") end -- remove plural s
	if lookForwL == 0 then msg = "Textobject not found within the line." end
	M.notify(msg, "notfound")
end

--------------------------------------------------------------------------------
-- TREESITTER UTILS

---get node at cursor and validate that the user has at least nvim 0.9
---@return nil|TSNode nil if no node or nvim version too old
function M.getNodeAtCursor()
	if vim.treesitter.get_node == nil then
		M.notify("This textobj requires least nvim 0.9.", "warn")
		return nil
	end
	return vim.treesitter.get_node()
end

---@param node TSNode
---@return string
function M.getNodeText(node) return vim.treesitter.get_node_text(node, 0) end

---@return boolean
function M.isVisualLineMode()
	local modeWithV = vim.fn.mode():find("V")
	return modeWithV ~= nil
end

---sets the selection for the textobj (linewise)
---@param startline integer
---@param endline integer
function M.setLinewiseSelection(startline, endline)
	-- save last position in jumplist (see #86)
	M.normal("m`")
	vim.api.nvim_win_set_cursor(0, { startline, 0 })
	if not M.isVisualLineMode() then M.normal("V") end
	M.normal("o")
	vim.api.nvim_win_set_cursor(0, { endline, 0 })
end

---@param lineNr number
---@return boolean|nil whether given line is blank line
function M.isBlankLine(lineNr)
	local lastLine = vim.api.nvim_buf_line_count(0)
	if lineNr > lastLine or lineNr < 1 then return nil end
	local lineContent = M.getline(lineNr)
	return lineContent:find("^%s*$") ~= nil
end

--------------------------------------------------------------------------------
return M

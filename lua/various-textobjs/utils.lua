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
---@param level? "info"|"trace"|"debug"|"warn"|"error"
function M.notify(msg, level)
	if not level then level = "info" end
	vim.notify(msg, vim.log.levels[level:upper()], { title = "nvim-various-textobjs" })
end

---notification when no textobj could be found
---@param lookForwL integer number of lines the plugin tried to look forward
function M.notFoundMsg(lookForwL)
	if not require("various-textobjs.config").config.notifyNotFound then return end
	local msg = "Textobject not found within the next " .. tostring(lookForwL) .. " lines."
	if lookForwL == 1 then msg = msg:gsub("s%.$", ".") end -- remove plural s
	M.notify(msg, "warn")
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

--------------------------------------------------------------------------------
return M

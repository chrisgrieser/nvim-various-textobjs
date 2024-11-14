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
return M

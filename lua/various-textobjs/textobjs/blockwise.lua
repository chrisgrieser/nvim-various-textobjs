local M = {}
local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

---Column Textobj (blockwise up and/or down until indent or shorter line)
---@param direction number Direction: +1 for "down" (default), -1 for "up", 0 for both
function M.column(direction)

	if direction == 0 then
		M.column(-1)
		u.normal("oO")
		M.column(1)
		return
	end

	direction = direction == -1 and direction or 1
	local key = direction == -1 and "k" or "j"

	local lastLnum = vim.api.nvim_buf_line_count(0)
	local startRow = vim.api.nvim_win_get_cursor(0)[1]
	local trueCursorCol = vim.fn.virtcol(".") -- virtcol accurately accounts for tabs as indentation
	local extraColumns = vim.v.count1 - 1 -- before running other :normal commands, since they change v:count

	local nextLnum = startRow

	repeat
		nextLnum = nextLnum + direction
		if nextLnum > lastLnum or nextLnum < 0 then break end
		local trueLineLength = #u.getline(nextLnum):gsub("\t", string.rep(" ", vim.bo.tabstop))
		local shorterLine = trueLineLength <= trueCursorCol
		local hitsIndent = trueCursorCol <= vim.fn.indent(nextLnum)
	until hitsIndent or shorterLine
	local linesToMove = direction*(nextLnum - startRow) - 1

	-- SET POSITION
	u.saveJumpToJumplist()

	-- start visual block mode ( requires special character `^V`)
	if not (vim.fn.mode() == "") then vim.cmd.execute([["normal! \<C-v>"]]) end

	-- not using `setCursor`, since its column-positions are messed up by tab indentation
	-- not using `G` to go down lines, since affected by `opt.startofline`
	if linesToMove > 0 then u.normal(tostring(linesToMove) .. key) end
	if extraColumns > 0 then u.normal(tostring(extraColumns) .. "l") end
end

--------------------------------------------------------------------------------
return M

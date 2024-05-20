local u = require("various-textobjs.utils")

local M = {}
local fn = vim.fn
local bo = vim.bo
local getCursor = vim.api.nvim_win_get_cursor

--------------------------------------------------------------------------------

---Column Textobj (blockwise down until indent or shorter line)
function M.column()
	local lastLnum = fn.line("$")
	local startRow = getCursor(0)[1]
	local trueCursorCol = fn.virtcol(".") -- virtcol accurately accounts for tabs as indentation
	local extraColumns = vim.v.count1 - 1 -- has to be done before running the other :normal commands, since they change v:count
	local nextLnum = startRow

	repeat
		nextLnum = nextLnum + 1
		if nextLnum > lastLnum then break end
		local trueLineLength = #u.getline(nextLnum):gsub("\t", string.rep(" ", bo.tabstop))
		local shorterLine = trueLineLength <= trueCursorCol
		local hitsIndent = trueCursorCol <= fn.indent(nextLnum)
	until hitsIndent or shorterLine
	local linesDown = nextLnum - 1 - startRow

	-- save last position in jumplist
	u.normal("m`")

	-- start visual block mode
	-- INFO requires special character `^V`
	if not (fn.mode() == "") then vim.cmd.execute([["normal! \<C-v>"]]) end

	-- set position
	-- not using `setCursor`, since its column-positions are messed up by tab indentation
	-- not using `G` to go down lines, since affected by `opt.startofline`
	if linesDown > 0 then u.normal(tostring(linesDown) .. "j") end
	if extraColumns > 0 then u.normal(tostring(extraColumns) .. "l") end
end

--------------------------------------------------------------------------------
return M

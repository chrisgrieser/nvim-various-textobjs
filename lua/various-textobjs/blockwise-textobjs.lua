local M = {}
local fn = vim.fn
local bo = vim.bo
local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

---Column Textobj (blockwise down until indent or shorter line)
function M.column()
	local lastLnum = fn.line("$")
	local nextLnum, cursorCol = unpack(u.getCursor(0))
	local extraColumns = vim.v.count1 - 1 -- has to be done before running the other :normal commands, since they change v:count

	-- get accurate cursorCol (account for tabs/spaces properly)
	if not bo.expandtab then
		local indentLevel = (fn.indent(".") / bo.tabstop) ---@diagnostic disable-line: param-type-mismatch
		cursorCol = cursorCol + (indentLevel * (bo.tabstop - 1))
	end

	repeat
		nextLnum = nextLnum + 1
		if nextLnum > lastLnum then break end -- break here, since after end of file, getline will fail
		local trueLineLength = #u.getline(nextLnum):gsub("\t", string.rep(" ", bo.tabstop)) ---@diagnostic disable-line: undefined-field
		local shorterLine = trueLineLength < cursorCol
		local hitsIndent = cursorCol < fn.indent(nextLnum)
	until hitsIndent or shorterLine
	nextLnum = nextLnum - 1

	-- start visual block mode
	if not (fn.mode() == "CTRL-V") then vim.cmd.execute([["normal! \<C-v>"]]) end

	u.normal(nextLnum .. "G")
	if extraColumns > 0 then u.normal(tostring(extraColumns) .. "l") end
end

--------------------------------------------------------------------------------
return M

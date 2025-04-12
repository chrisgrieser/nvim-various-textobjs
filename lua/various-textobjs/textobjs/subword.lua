local M = {}
local core = require("various-textobjs.charwise-core")
local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

---@param scope "inner"|"outer"
function M.subword(scope)
	-- needs to be saved, since using a textobj always results in visual mode
	local initialMode = vim.fn.mode()

	local patterns = {
		camelOrLowercase = "()%a[%l%d]+([_-]?)",
		UPPER_CASE = "()%u[%u%d]+([_-]?)",
		number = "()%d+([_-]?)",
		tieloser_singleChar = "()%a([_-]?)", -- e.g., "x" in "xSide" or "sideX" (see #75)
	}
	local row, startCol, endCol = core.selectClosestTextobj(patterns, scope, 0)
	if not (row and startCol and endCol) then return end

	-----------------------------------------------------------------------------
	-- EXTRA ADJUSTMENTS
	local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
	startCol, endCol = startCol + 1, endCol + 1 -- adjust for lua indexing for `:sub`
	local charBefore = line:sub(startCol - 1, startCol - 1)
	local charAfter = line:sub(endCol + 1, endCol + 1)
	local firstChar = line:sub(startCol, startCol)
	local lastChar = line:sub(endCol, endCol)

	-- LEADING `-_` ON LAST PART OF SUBWORD
	-- 1. The outer pattern checks for subwords that with potentially trailing
	-- `_-`, however, if the subword is the last segment of a word, there is
	-- potentially also a leading `_-` which should be included (see #83).
	-- 2. Checking for those with patterns is not possible, since subwords
	-- without any trailing/leading chars are always considered the closest (and
	-- thus prioritized by `selectClosestTextobj`), even though the usage
	-- expectation is that `subword` should be more greedy.
	-- 3. Thus, we check if we are on the last part of a snake_cased word, and if
	-- so, add the leading `_-` to the selection.
	local onLastSnakeCasePart = charBefore:find("[_-]") and not lastChar:find("[_-]")
	if scope == "outer" and onLastSnakeCasePart then
		-- `o`: to start of selection, `h`: select char before `o`: back to end
		u.normal("oho")
	end

	-- CAMEL/PASCAL CASE DEALING
	-- When deleting the start of a camelCased word, the result should still be
	-- camelCased and not PascalCased (see #113).
	local noCamelToPascalCase =
		require("various-textobjs.config.config").config.textobjs.subword.noCamelToPascalCase
	if noCamelToPascalCase then
		local isCamel = vim.fn.expand("<cword>"):find("%l%u")
		local notPascal = not firstChar:find("%u") -- see https://github.com/chrisgrieser/nvim-various-textobjs/issues/113#issuecomment-2752632884
		local nextIsPascal = charAfter:find("%u")
		local isWordStart = charBefore:find("%W") or charBefore == ""
		local isDeletion = vim.v.operator == "d"
		local notVisual = not initialMode:find("[Vv]") -- see #121
		if isCamel and notPascal and nextIsPascal and isWordStart and isDeletion and notVisual then
			-- lowercase the following subword
			local updatedLine = line:sub(1, endCol) .. charAfter:lower() .. line:sub(endCol + 2)
			vim.api.nvim_buf_set_lines(0, row - 1, row, false, { updatedLine })
		end
	end
end

--------------------------------------------------------------------------------
return M

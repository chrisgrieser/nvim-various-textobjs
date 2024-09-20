local M = {}

local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

-- Get the position of the first non-whitespace character
local function get_first_non_whitespace_col(lnum)
	local line = vim.fn.getline(lnum)
	local _, col = line:find("^%s*")
	return col and col + 1 or 1
end

--- Go to top or bottom of indentation scope based on position.
---@param position "top"|"bottom"  -- The position to go to within the indentation scope.
---@param startBorder "inner"|"outer"  -- Whether to include or exclude the start border.
---@param endBorder "inner"|"outer"  -- Whether to include or exclude the end border.
---@param blankLines? "withBlanks"|"noBlanks"  -- Whether to include blank lines in the scope (default: "withBlanks").
function M.go_to_indentation(position, startBorder, endBorder, blankLines)
	if not blankLines then blankLines = "withBlanks" end

	local curLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLine = vim.api.nvim_buf_line_count(0)
	while u.isBlankLine(curLnum) do -- When on blank line, use next line.
		if lastLine == curLnum then
			u.notify("No indented line found.", "notfound")
			return
		end
		curLnum = curLnum + 1
	end

	local indentOfStart = vim.fn.indent(curLnum)
	if indentOfStart == 0 then
		u.notify("Current line is not indented.", "notfound")
		return false -- Return value needed for greedyOuterIndentation textobj
	end

	local prevLnum = curLnum - 1
	local nextLnum = curLnum + 1

	while
		prevLnum > 0
		and (
			(blankLines == "withBlanks" and u.isBlankLine(prevLnum))
			or vim.fn.indent(prevLnum) >= indentOfStart
		)
	do
		prevLnum = prevLnum - 1
	end
	while
		nextLnum <= lastLine
		and (
			(blankLines == "withBlanks" and u.isBlankLine(nextLnum))
			or vim.fn.indent(nextLnum) >= indentOfStart
		)
	do
		nextLnum = nextLnum + 1
	end

	-- Adjust start and end borders based on parameters.
	if startBorder == "inner" then prevLnum = prevLnum + 1 end
	if endBorder == "inner" then nextLnum = nextLnum - 1 end

	while u.isBlankLine(nextLnum) do
		nextLnum = nextLnum - 1
	end

	-- Go to the appropriate position: top or bottom of the scope.
	if position == "top" then
		vim.api.nvim_win_set_cursor(0, { prevLnum, get_first_non_whitespace_col(prevLnum) - 1 })
	elseif position == "bottom" then
		vim.api.nvim_win_set_cursor(0, { nextLnum, get_first_non_whitespace_col(nextLnum) - 1 })
	else
		u.notify("Invalid position. Must be 'top' or 'bottom'.", "error")
	end
end

return M

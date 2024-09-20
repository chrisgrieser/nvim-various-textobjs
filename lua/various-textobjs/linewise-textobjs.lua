local M = {}

local u = require("various-textobjs.utils")
local config = require("various-textobjs.config").config
--------------------------------------------------------------------------------

-- next *closed* fold
---@param scope "inner"|"outer" outer adds one line after the fold
function M.closedFold(scope)
	local startLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLine = vim.api.nvim_buf_line_count(0)
	local startedOnFold = vim.fn.foldclosed(startLnum) > 0
	local foldStart, foldEnd

	if startedOnFold then
		foldStart = vim.fn.foldclosed(startLnum)
		foldEnd = vim.fn.foldclosedend(startLnum)
	else
		foldStart = startLnum
		repeat
			if foldStart >= lastLine or foldStart > (config.lookForwardBig + startLnum) then
				u.notFoundMsg(config.lookForwardBig)
				return
			end
			foldStart = foldStart + 1
			local reachedClosedFold = vim.fn.foldclosed(foldStart) > 0
		until reachedClosedFold
		foldEnd = vim.fn.foldclosedend(foldStart)
	end
	if scope == "outer" and (foldEnd + 1 <= lastLine) then foldEnd = foldEnd + 1 end

	-- fold has to be opened for so line can be correctly selected
	vim.cmd(("%d,%d foldopen"):format(foldStart, foldEnd))
	u.setLinewiseSelection(foldStart, foldEnd)

	-- if yanking, close the fold afterwards again.
	-- (For the other operators, opening the fold does not matter (d) or is desirable (gu).)
	if vim.v.operator == "y" then vim.cmd(("%d,%d foldclose"):format(foldStart, foldEnd)) end
end

---Textobject for the entire buffer content
function M.entireBuffer()
	-- FIX folds at the first or last line cause lines being left out
	vim.opt_local.foldenable = false

	local lastLine = vim.api.nvim_buf_line_count(0)
	u.setLinewiseSelection(1, lastLine)

	vim.opt_local.foldenable = true
end

---rest of paragraph (linewise)
function M.restOfParagraph()
	if not u.isVisualLineMode() then u.normal("V") end
	u.normal("}")

	-- one up, except on last line
	local curLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLine = vim.api.nvim_buf_line_count(0)
	if curLnum ~= lastLine then u.normal("k") end
end

---Md Fenced Code Block Textobj
---@param scope "inner"|"outer" inner excludes the backticks
function M.mdFencedCodeBlock(scope)
	local cursorLnum = vim.api.nvim_win_get_cursor(0)[1]
	local codeBlockPattern = "^```%w*$"

	-- scan buffer for all code blocks, add beginnings & endings to a table each
	local cbBegin = {}
	local cbEnd = {}
	local allLines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
	local i = 1
	for _, line in pairs(allLines) do
		if line:find(codeBlockPattern) then
			if #cbBegin == #cbEnd then
				table.insert(cbBegin, i)
			else
				table.insert(cbEnd, i)
			end
		end
		i = i + 1
	end

	if #cbBegin > #cbEnd then table.remove(cbBegin) end -- incomplete codeblock

	-- determine cursor location in a codeblock
	local j = 0
	repeat
		j = j + 1
		if j > #cbBegin then
			u.notFoundMsg(config.lookForwardBig)
			return
		end
		local cursorInBetween = (cbBegin[j] <= cursorLnum) and (cbEnd[j] >= cursorLnum)
		-- seek forward for a codeblock
		local cursorInFront = (cbBegin[j] > cursorLnum)
			and (cbBegin[j] <= cursorLnum + config.lookForwardBig)
	until cursorInBetween or cursorInFront

	local start = cbBegin[j]
	local ending = cbEnd[j]
	if scope == "inner" then
		start = start + 1
		ending = ending - 1
	end

	u.setLinewiseSelection(start, ending)
end

---lines visible in window textobj
function M.visibleInWindow()
	local start = vim.fn.line("w0")
	local ending = vim.fn.line("w$")
	u.setLinewiseSelection(start, ending)
end

-- from cursor line to last visible line in window
function M.restOfWindow()
	local start = vim.fn.line(".")
	local ending = vim.fn.line("w$")
	u.setLinewiseSelection(start, ending)
end

--------------------------------------------------------------------------------

---indentation textobj
---@param startBorder "inner"|"outer"
---@param endBorder "inner"|"outer"
---@param blankLines? "withBlanks"|"noBlanks"
function M.indentation(startBorder, endBorder, blankLines)
	if not blankLines then blankLines = "withBlanks" end

	local curLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLine = vim.api.nvim_buf_line_count(0)
	while u.isBlankLine(curLnum) do -- when on blank line, use next line
		if lastLine == curLnum then
			u.notify("No indented line found.", "notfound")
			return
		end
		curLnum = curLnum + 1
	end

	local indentOfStart = vim.fn.indent(curLnum)
	if indentOfStart == 0 then
		u.notify("Current line is not indented.", "notfound")
		return false -- return value needed for greedyOuterIndentation textobj
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

	-- differentiate ai and ii
	if startBorder == "inner" then prevLnum = prevLnum + 1 end
	if endBorder == "inner" then nextLnum = nextLnum - 1 end

	while u.isBlankLine(nextLnum) do
		nextLnum = nextLnum - 1
	end

	u.setLinewiseSelection(prevLnum, nextLnum)
end

---from cursor position down all lines with same or higher indentation;
---essentially `ii` downwards
function M.restOfIndentation()
	local startLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLine = vim.api.nvim_buf_line_count(0)
	local curLnum = startLnum
	while u.isBlankLine(curLnum) do -- when on blank line, use next line
		if lastLine == curLnum then return end
		curLnum = curLnum + 1
	end

	local indentOfStart = vim.fn.indent(curLnum)
	if indentOfStart == 0 then
		u.notify("Current line is not indented.", "notfound")
		return
	end

	local nextLnum = curLnum + 1

	while u.isBlankLine(nextLnum) or vim.fn.indent(nextLnum) >= indentOfStart do
		if nextLnum > lastLine then break end
		nextLnum = nextLnum + 1
	end

	u.setLinewiseSelection(startLnum, nextLnum - 1)
end

---outer indentation, expanded until the next blank lines in both directions
---@param scope "inner"|"outer" outer adds a blank, like ip/ap textobjs
function M.greedyOuterIndentation(scope)
	-- select outer indentation
	local invalid = M.indentation("outer", "outer") == false
	if invalid then return end
	u.normal("o{j") -- to next blank line above
	u.normal("o}") -- to next blank line down
	if scope == "inner" then u.normal("k") end -- exclude blank below if inner
end

--------------------------------------------------------------------------------

---@param lnum number
---@return boolean
local function isCellBorder(lnum)
	local cellMarker = vim.bo.commentstring:format("%%")
	local line = u.getline(lnum)
	return vim.startswith(vim.trim(line), cellMarker)
end

-- for plugins like NotebookNavigator.nvim
---@param scope "inner"|"outer" outer includes bottom cell border
function M.notebookCell(scope)
	if vim.bo.commentstring == "" then
		u.notify("Buffer has no commentstring set.", "warn")
		return
	end

	local curLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLine = vim.api.nvim_buf_line_count(0)
	local prevLnum = curLnum
	local nextLnum = isCellBorder(curLnum) and curLnum + 1 or curLnum

	while prevLnum > 0 and not isCellBorder(prevLnum) do
		prevLnum = prevLnum - 1
	end
	while nextLnum <= lastLine and not isCellBorder(nextLnum) do
		nextLnum = nextLnum + 1
	end

	-- outer includes bottom cell border
	if scope == "outer" and nextLnum < lastLine then nextLnum = nextLnum + 1 end

	u.setLinewiseSelection(prevLnum + 1, nextLnum - 1)
end

--------------------------------------------------------------------------------
return M

local M = {}
local fn = vim.fn

local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

---@return boolean
local function isVisualLineMode()
	local modeWithV = vim.fn.mode():find("V")
	return modeWithV ~= nil
end

---sets the selection for the textobj (linewise)
---@param startline integer
---@param endline integer
local function setLinewiseSelection(startline, endline)
	u.setCursor(0, { startline, 0 })
	if not isVisualLineMode() then u.normal("V") end
	u.normal("o")
	u.setCursor(0, { endline, 0 })
end

---@param lineNr number
---@return boolean whether given line is blank line
local function isBlankLine(lineNr)
	local lineContent = u.getline(lineNr)
	return lineContent:find("^%s*$") == 1
end

--------------------------------------------------------------------------------

-- next *closed* fold
---@param inner boolean outer adds one line after the fold
---@param lookForwL integer number of lines to look forward for the textobj
function M.closedFold(inner, lookForwL)
	local startLnum = fn.line(".")
	local lastLine = fn.line("$")
	local startedOnFold = fn.foldclosed(startLnum) > 0
	local foldStart, foldEnd

	if startedOnFold then
		foldStart = fn.foldclosed(startLnum)
		foldEnd = fn.foldclosedend(startLnum)
	else
		foldStart = startLnum
		repeat
			if foldStart >= lastLine or foldStart > (lookForwL + startLnum) then
				u.notFoundMsg(lookForwL)
				return
			end
			foldStart = foldStart + 1
			local reachedClosedFold = fn.foldclosed(foldStart) > 0
		until reachedClosedFold
		foldEnd = fn.foldclosedend(foldStart)
	end
	if not inner and (foldEnd + 1 <= lastLine) then foldEnd = foldEnd + 1 end

	-- fold has to be opened for so line can be correctly selected
	vim.cmd(("%d,%d foldopen"):format(foldStart, foldEnd))
	setLinewiseSelection(foldStart, foldEnd)

	-- if yanking, close the fold afterwards again.
	-- (For the other operators, opening the fold does not matter (d) or is desirable (gu).)
	if vim.v.operator == "y" then vim.cmd(("%d,%d foldclose"):format(foldStart, foldEnd)) end
end

---Textobject for the entire buffer content
function M.entireBuffer() setLinewiseSelection(1, fn.line("$")) end

---rest of paragraph (linewise)
function M.restOfParagraph()
	if not isVisualLineMode() then u.normal("V") end
	u.normal("}")
	if fn.line(".") ~= fn.line("$") then u.normal("k") end -- one up, except on last line
end

---Md Fenced Code Block Textobj
---@param inner boolean inner excludes the backticks
---@param lookForwL integer number of lines to look forward for the textobj
function M.mdFencedCodeBlock(inner, lookForwL)
	local cursorLnum = fn.line(".")
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

	if #cbBegin > #cbEnd then table.remove(cbEnd) end -- incomplete codeblock

	-- determine cursor location in a codeblock
	local j = 0
	repeat
		j = j + 1
		if j > #cbBegin then
			u.notFoundMsg(lookForwL)
			return
		end
		local cursorInBetween = (cbBegin[j] <= cursorLnum) and (cbEnd[j] >= cursorLnum)
		-- seek forward for a codeblock
		local cursorInFront = (cbBegin[j] > cursorLnum) and (cbBegin[j] <= cursorLnum + lookForwL)
	until cursorInBetween or cursorInFront

	local start = cbBegin[j]
	local ending = cbEnd[j]
	if inner then
		start = start + 1
		ending = ending - 1
	end

	setLinewiseSelection(start, ending)
end

--------------------------------------------------------------------------------

---indentation textobj
---@param noStartBorder boolean exclude the startline
---@param noEndBorder boolean exclude the endline
function M.indentation(noStartBorder, noEndBorder)
	local curLnum = fn.line(".")
	local lastLine = fn.line("$")
	while isBlankLine(curLnum) do -- when on blank line, use next line
		if lastLine == curLnum then return end
		curLnum = curLnum + 1
	end

	local indentOfStart = fn.indent(curLnum)
	if indentOfStart == 0 then
		vim.notify("Current line is not indented.", vim.log.levels.WARN)
		return
	end

	local prevLnum = curLnum - 1
	local nextLnum = curLnum + 1

	while prevLnum > 0 and (isBlankLine(prevLnum) or fn.indent(prevLnum) >= indentOfStart) do
		prevLnum = prevLnum - 1
	end
	while nextLnum <= lastLine and (isBlankLine(nextLnum) or fn.indent(nextLnum) >= indentOfStart) do
		nextLnum = nextLnum + 1
	end

	-- differentiate ai and ii
	if noStartBorder then prevLnum = prevLnum + 1 end
	if noEndBorder then nextLnum = nextLnum - 1 end

	while isBlankLine(nextLnum) do
		nextLnum = nextLnum - 1
	end

	setLinewiseSelection(prevLnum, nextLnum)
end

---from cursor position down all lines with same or higher indentation;
---essentially `ii` downwards
function M.restOfIndentation()
	local startLnum = fn.line(".")
	local lastLine = fn.line("$")
	local curLnum = startLnum
	while isBlankLine(curLnum) do -- when on blank line, use next line
		if lastLine == curLnum then return end
		curLnum = curLnum + 1
	end

	local indentOfStart = fn.indent(curLnum)
	if indentOfStart == 0 then
		vim.notify("Current line is not indented.", vim.log.levels.WARN)
		return
	end

	local nextLnum = curLnum + 1

	while isBlankLine(nextLnum) or fn.indent(nextLnum) >= indentOfStart do
		if nextLnum > lastLine then break end
		nextLnum = nextLnum + 1
	end

	setLinewiseSelection(startLnum, nextLnum - 1)
end

--------------------------------------------------------------------------------
return M

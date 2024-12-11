local M = {}
local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

---sets the selection for the textobj (linewise)
---@param startline integer
---@param endline integer
local function setLinewiseSelection(startline, endline)
	u.saveJumpToJumplist()
	vim.api.nvim_win_set_cursor(0, { startline, 0 })
	if vim.fn.mode() ~= "V" then u.normal("V") end
	u.normal("o")
	vim.api.nvim_win_set_cursor(0, { endline, 0 })
end

---@param lineNr number
---@return boolean|nil -- nil when lineNr is out of bounds
local function isBlankLine(lineNr)
	local lastLine = vim.api.nvim_buf_line_count(0)
	if lineNr > lastLine or lineNr < 1 then return nil end
	local lineContent = u.getline(lineNr)
	return lineContent:find("^%s*$") ~= nil
end

--------------------------------------------------------------------------------

---@param scope "inner"|"outer" outer adds one line after the fold
function M.closedFold(scope)
	local startLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLine = vim.api.nvim_buf_line_count(0)
	local startedOnFold = vim.fn.foldclosed(startLnum) > 0
	local foldStart, foldEnd
	local bigForward = require("various-textobjs.config").config.forwardLooking.big

	if startedOnFold then
		foldStart = vim.fn.foldclosed(startLnum)
		foldEnd = vim.fn.foldclosedend(startLnum)
	else
		foldStart = startLnum
		repeat
			if foldStart >= lastLine or foldStart > (bigForward + startLnum) then
				u.notFoundMsg(bigForward)
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
	setLinewiseSelection(foldStart, foldEnd)

	-- if yanking, close the fold afterwards again.
	-- (For the other operators, opening the fold does not matter (d) or is desirable (gu).)
	if vim.v.operator == "y" then vim.cmd(("%d,%d foldclose"):format(foldStart, foldEnd)) end
end

function M.entireBuffer()
	-- FIX folds at the first or last line cause lines being left out
	local foldWasEnabled = vim.opt_local.foldenable:get() ---@diagnostic disable-line: undefined-field
	if foldWasEnabled then vim.opt_local.foldenable = false end

	local lastLine = vim.api.nvim_buf_line_count(0)
	setLinewiseSelection(1, lastLine)

	if foldWasEnabled then vim.opt_local.foldenable = true end
end

---rest of paragraph (linewise)
function M.restOfParagraph()
	if vim.fn.mode() ~= "V" then u.normal("V") end
	u.normal("}")

	-- one up, except on last line
	local curLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLine = vim.api.nvim_buf_line_count(0)
	if curLnum ~= lastLine then u.normal("k") end
end

---@param scope "inner"|"outer" inner excludes the backticks
function M.mdFencedCodeBlock(scope)
	local cursorLnum = vim.api.nvim_win_get_cursor(0)[1]
	local codeBlockPattern = "```%w*$" -- only check end of line, see #78
	local bigForward = require("various-textobjs.config").config.forwardLooking.big

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
			u.notFoundMsg(bigForward)
			return
		end
		local cursorInBetween = (cbBegin[j] <= cursorLnum) and (cbEnd[j] >= cursorLnum)
		-- seek forward for a codeblock
		local cursorInFront = (cbBegin[j] > cursorLnum) and (cbBegin[j] <= cursorLnum + bigForward)
	until cursorInBetween or cursorInFront

	local start = cbBegin[j]
	local ending = cbEnd[j]
	if scope == "inner" then
		start = start + 1
		ending = ending - 1
	end

	setLinewiseSelection(start, ending)
end

function M.visibleInWindow()
	local start = vim.fn.line("w0")
	local ending = vim.fn.line("w$")
	setLinewiseSelection(start, ending)
end

function M.restOfWindow()
	local start = vim.fn.line(".")
	local ending = vim.fn.line("w$")
	setLinewiseSelection(start, ending)
end

--------------------------------------------------------------------------------

---@param startBorder "inner"|"outer"
---@param endBorder "inner"|"outer"
---@return boolean success
function M.indentation(startBorder, endBorder, oldBlankSetting)
	-- DEPRECATION (2024-12-06)
	if oldBlankSetting ~= nil then
		local msg =
			"`.indentation()` does not use a 3rd argument anymore. Use the config `textobjs.indent.blanksAreDelimiter` instead."
		u.warn(msg)
	end
	local blanksDelimit =
		require("various-textobjs.config").config.textobjs.indentation.blanksAreDelimiter

	-- when on blank line seek for next non-blank line to start
	local curLnum = vim.api.nvim_win_get_cursor(0)[1]
	while isBlankLine(curLnum) do
		curLnum = curLnum + 1
	end
	local startIndent = vim.fn.indent(curLnum) -- `-1` for out of bounds
	if startIndent < 1 then
		u.warn("Current line is not indented.")
		return false
	end
	local prevLn = curLnum - 1
	local nextLn = curLnum + 1
	local lastLine = vim.api.nvim_buf_line_count(0)

	-- seek backwards/forwards until meeting line with higher indentation, blank
	-- (if used as delimiter), or start/end of file
	while (isBlankLine(prevLn) and not blanksDelimit) or vim.fn.indent(prevLn) >= startIndent do
		prevLn = prevLn - 1
		if prevLn == 0 then break end
	end
	while (isBlankLine(nextLn) and not blanksDelimit) or vim.fn.indent(nextLn) >= startIndent do
		nextLn = nextLn + 1
		if nextLn > lastLine then break end
	end

	-- at start/end of file, abort when with `outer` or go back a step for `inner`
	if prevLn == 0 and startBorder == "outer" then
		u.notFoundMsg("No top border found.")
		return false
	elseif nextLn > lastLine and endBorder == "outer" then
		u.notFoundMsg("No bottom border found.")
		return false
	end
	if startBorder == "inner" then prevLn = prevLn + 1 end
	if endBorder == "inner" then nextLn = nextLn - 1 end

	-- keep blanks in case of missing bottom border (e.g. for python)
	while isBlankLine(nextLn) do
		nextLn = nextLn - 1
	end

	setLinewiseSelection(prevLn, nextLn)
	return true
end

---outer indentation, expanded until the next blank lines in both directions
---@param scope "inner"|"outer" outer adds a blank, like ip/ap textobjs
function M.greedyOuterIndentation(scope)
	local success = M.indentation("outer", "outer")
	if not success then return end

	u.normal("o{j") -- to next blank line above
	u.normal("o}") -- to next blank line down
	if scope == "inner" then u.normal("k") end -- exclude blank below if inner
end

---from cursor position down all lines with same or higher indentation;
---essentially `ii` downwards
function M.restOfIndentation()
	local startLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLine = vim.api.nvim_buf_line_count(0)
	local curLnum = startLnum
	while isBlankLine(curLnum) do -- when on blank line, use next line
		if lastLine == curLnum then return end
		curLnum = curLnum + 1
	end

	local indentOfStart = vim.fn.indent(curLnum)
	if indentOfStart == 0 then
		u.warn("Current line is not indented.")
		return
	end

	local nextLnum = curLnum + 1

	while isBlankLine(nextLnum) or vim.fn.indent(nextLnum) >= indentOfStart do
		if nextLnum > lastLine then break end
		nextLnum = nextLnum + 1
	end

	setLinewiseSelection(startLnum, nextLnum - 1)
end

--------------------------------------------------------------------------------

---@param scope "inner"|"outer" outer includes bottom cell border
function M.notebookCell(scope)
	local function isCellBorder(lnum)
		local cellMarker = vim.bo.commentstring:format("%%")
		local line = u.getline(lnum)
		return vim.startswith(vim.trim(line), cellMarker)
	end

	if vim.bo.commentstring == "" then
		u.warn("Buffer has no commentstring set.")
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

	setLinewiseSelection(prevLnum + 1, nextLnum - 1)
end

--------------------------------------------------------------------------------
return M

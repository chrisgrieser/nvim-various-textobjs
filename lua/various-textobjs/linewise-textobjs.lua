local M = {}

local u = require("various-textobjs.utils")
local config = require("various-textobjs.config").config
--------------------------------------------------------------------------------

---@return boolean
local function isVisualLineMode()
	local modeWithV = vim.fn.mode():find("V")
	return modeWithV ~= nil
end

---@return boolean
local function isVisualBlockMode()
	local modeWithCTRL_V = vim.fn.mode():find("")
	return modeWithCTRL_V ~= nil
end

---@return boolean
local function isVisualAnyMode()
	local modeWithVvCTRL_V = vim.fn.mode():find("[vV]")
	return modeWithVvCTRL_V ~= nil
end

---sets the selection for the textobj (linewise)
---@param startline integer
---@param endline integer
local function setLinewiseSelection(startline, endline)
	-- save last position in jumplist (see #86)
	u.normal("m`")
	vim.api.nvim_win_set_cursor(0, { startline, 0 })
	if not isVisualLineMode() then u.normal("V") end
	u.normal("o")
	vim.api.nvim_win_set_cursor(0, { endline, 0 })
end

-- Gets the (1,0)-indexed visual selection endpoints
-- Unlike vim.fn.getpos("v") the endpoints are relative to the current cursor position
---@return pos? opposite
---@return pos? adjacent
---@return pos? adjacent-opposite
local function getSelectionEndpoints()
	if not isVisualAnyMode() then return end
	u.normal("o")
	local b = vim.api.nvim_win_get_cursor(0)
	if isVisualBlockMode() then
		u.normal("O")
		local c = vim.api.nvim_win_get_cursor(0)
		u.normal("o")
		local d = vim.api.nvim_win_get_cursor(0)
		u.normal("O")
		return b, c, d
	end
	u.normal("o")
	return b
end

---@param lineNr number
---@return boolean|nil whether given line is blank line
local function isBlankLine(lineNr)
	local lastLine = vim.api.nvim_buf_line_count(0)
	if lineNr > lastLine or lineNr < 1 then return nil end
	local lineContent = u.getline(lineNr)
	return lineContent:find("^%s*$") ~= nil
end

--------------------------------------------------------------------------------

-- next *closed* fold
---@param scope "inner"|"outer" outer adds one line after the fold
function M.closedFold(scope)
	local startLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLine = vim.api.nvim_buf_line_count(0)
	local startedOnFold = vim.fn.foldclosed(startLnum) > 0
	local count = vim.v.count1
	local selectionTailLnum = (getSelectionEndpoints() or {})[1]
	local replaceSelection = selectionTailLnum or startedOnFold and startLnum == selectionTailLnum
	local foldStart, foldEnd

	if startedOnFold then
		foldStart = vim.fn.foldclosed(startLnum)
		foldEnd = vim.fn.foldclosedend(startLnum)
		count = count - 1
	end
	if count > 0 then
		foldStart = startLnum
		local lastClosedFold
		repeat
			if foldStart >= lastLine or foldStart > (config.lookForwardBig + startLnum) then
				u.notFoundMsg(config.lookForwardBig)
				return
			end
			foldStart = foldStart + 1
			local closedFold = vim.fn.foldclosed(foldStart)
			local reachedClosedFold = closedFold > 0
			if reachedClosedFold and closedFold ~= lastClosedFold then
				count = count - 1
				lastClosedFold = closedFold
			end
		until count == 0
		foldEnd = vim.fn.foldclosedend(foldStart)
	end

	local selectionStart = replaceSelection and foldStart
		or (isVisualAnyMode() and selectionTailLnum or foldStart) -- + (foldEnd - foldStart)
	if scope == "outer" and (foldEnd + 1 <= lastLine) then foldEnd = foldEnd + 1 end

	-- fold has to be opened for so line can be correctly selected
	vim.cmd(("%d,%d foldopen"):format(foldStart, foldEnd))
	setLinewiseSelection(selectionStart, foldEnd)

	-- if yanking, close the fold afterwards again.
	-- (For the other operators, opening the fold does not matter (d) or is desirable (gu).)
	if vim.v.operator == "y" then vim.cmd(("%d,%d foldclose"):format(foldStart, foldEnd)) end
end

---Textobject for the entire buffer content
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
	local count = vim.v.count1
	if not isVisualLineMode() then u.normal("V") end
	u.normal(count .. "}")

	-- one up, except on last line
	local curLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLine = vim.api.nvim_buf_line_count(0)
	if curLnum ~= lastLine then u.normal("k") end
	-- curLnum = vim.api.nvim_win_get_cursor(0)[1]
	-- if curLnum == initLnum and startsVisualLine then
	-- 	u.normal("2}")
	-- 	curLnum = vim.api.nvim_win_get_cursor(0)[1]
	-- 	if curLnum ~= lastLine then u.normal("k") end
	-- end
end

---Md Fenced Code Block Textobj
---@param scope "inner"|"outer" inner excludes the backticks
function M.mdFencedCodeBlock(scope)
	local cursorLnum = vim.api.nvim_win_get_cursor(0)[1]
	local codeBlockPattern = "^```%w*$"
	local count = vim.v.count1

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
	local selectionTailLnum = (getSelectionEndpoints() or {})[1]
	local replaceSelection = selectionTailLnum and cursorLnum == selectionTailLnum
	local instance = count
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
		if cursorInBetween or cursorInFront then instance = instance - 1 end
	until (cursorInBetween or cursorInFront) and instance <= 0

	local start = cbBegin[j]
	local ending = cbEnd[j]
	if replaceSelection then start = cbBegin[j - count + 1] end
	if scope == "inner" then
		start = start + 1
		ending = ending - 1
	end
	if not replaceSelection then
		if cursorLnum == ending then ending = cbBegin[j + 1] - 1 end
		start = selectionTailLnum
	end

	setLinewiseSelection(start, ending)
end

---lines visible in window textobj
function M.visibleInWindow()
	local start = vim.fn.line("w0")
	local ending = vim.fn.line("w$")
	setLinewiseSelection(start, ending)
end

-- from cursor line to last visible line in window
function M.restOfWindow()
	local start = vim.fn.line(".")
	local ending = vim.fn.line("w$")
	setLinewiseSelection(start, ending)
end

--------------------------------------------------------------------------------

-- the og indent-object is quite inconsistent
-- ai will stop right before the upper boundary depending on the indentation level (try 2 vs 4)
-- the selected indentation level is dictated by the cendpoint loc (e.g. same indent broken up
-- by a single line of a lower one)
-- thus, it replaces only if cendpoint is in a different indentation
-- if the min (minimum area of the object) is selected extends otherwise it replaces (blockobj
-- should always replace)
-- the min isn't of the closest obj near the cursor but the parentmost indentation under a cendpoint
-- ai/aI iter (once selected the min) will seek upwards by one whitespace or (^%S$)+(^%s$)* then use the seekd line as new
-- indentlevel instead of selecting parent indent (and includes extra uppper line)
-- ii iter (once selected the min) will seek upwards by one whitespace or (^%S$)+ then use the seekd line as new
-- indentlevel instead of selecting parent indent

---indentation textobj
---@param startBorder "inner"|"outer"
---@param endBorder "inner"|"innerWithBlanks"|"outer"
---@param blankLines? "withBlanks"|"noBlanks"
function M.indentation(startBorder, endBorder, blankLines)
	if not blankLines then blankLines = "withBlanks" end

	local curLnum = vim.api.nvim_win_get_cursor(0)[1]
	local firstLine = 1
	local lastLine = vim.api.nvim_buf_line_count(0)
	local count = vim.v.count1
	local selectionTailLnum = (getSelectionEndpoints() or {})[1]
	local prevLnum = curLnum
	local nextLnum = curLnum
	while isBlankLine(prevLnum) and prevLnum ~= firstLine do
		prevLnum = prevLnum - 1
	end
	while isBlankLine(nextLnum) and nextLnum ~= lastLine do
		nextLnum = nextLnum + 1
	end

	local userBorderUpper
	local userBorderLower
	local iterToParentInstance
	repeat
		local indentOfStart = math.max(vim.fn.indent(nextLnum), vim.fn.indent(prevLnum))
		if indentOfStart == 0 then
			u.notify("Target line is not indented.", "notfound")
			return "notIndented" -- return value needed for greedyOuterIndentation textobj
		end
		while
			prevLnum > firstLine
			and (
				(blankLines == "withBlanks" and isBlankLine(prevLnum))
				or vim.fn.indent(prevLnum) >= indentOfStart
			)
		do
			prevLnum = prevLnum - 1
		end
		while
			nextLnum < lastLine
			and (
				(blankLines == "withBlanks" and isBlankLine(nextLnum))
				or vim.fn.indent(nextLnum) >= indentOfStart
			)
		do
			nextLnum = nextLnum + 1
		end

		local noUpperBound = prevLnum == firstLine
			and (
				(blankLines == "withBlanks" and isBlankLine(firstLine))
				or vim.fn.indent(firstLine) >= indentOfStart
			)
		local noLowerBound = nextLnum == lastLine
			and (
				(blankLines == "withBlanks" and isBlankLine(lastLine))
				or vim.fn.indent(lastLine) >= indentOfStart
			)

		-- use separate variables to keep old Lnum values for future count/iter loops
		userBorderUpper = prevLnum
		userBorderLower = nextLnum

		-- differentiate ai and ii
		if
			(startBorder == "inner" or startBorder == "innerWithBlanks")
			and (userBorderUpper < lastLine and userBorderUpper < nextLnum)
			and not noUpperBound
		then
			userBorderUpper = userBorderUpper + 1
		end
		if
			(endBorder == "inner" or endBorder == "innerWithBlanks")
			and (userBorderLower > firstLine and userBorderLower > prevLnum)
			and not noLowerBound
		then
			userBorderLower = userBorderLower - 1
		end

		while startBorder == "inner" and isBlankLine(userBorderUpper) do
			userBorderUpper = userBorderUpper + 1
		end
		while endBorder == "inner" and isBlankLine(userBorderLower) do
			userBorderLower = userBorderLower - 1
		end
		count = count - 1

		-- ii has iteration limits, since it can lead to a crossBoundary state
		iterToParentInstance = (
			(userBorderUpper == selectionTailLnum and userBorderLower == curLnum)
			or (userBorderLower == selectionTailLnum and userBorderUpper == curLnum)
		) and isVisualLineMode()
	until not (iterToParentInstance or count > 0)

	-- makes nullop when endpoint is beyond object boundaries
	local crossBoundary = selectionTailLnum
		and (
			(prevLnum <= curLnum and curLnum < nextLnum and nextLnum < selectionTailLnum)
			or (selectionTailLnum < prevLnum and prevLnum < curLnum and curLnum <= nextLnum)
		)
	if crossBoundary then
		u.notify("Existing selection crosses object boundary.", "notfound")
		return "crossBoundary"
	end

	-- it should also disable iter for counts above 1 -- does this by itself?
	-- because it's a blockobj
	-- it never extend selection but always replaces it
	-- it isn't directional since count/iter should go to the parent match
	setLinewiseSelection(userBorderUpper, userBorderLower)
end

--TODO: use new indentation() logic
---from cursor position down all lines with same or higher indentation;
---essentially `ii` downwards
function M.restOfIndentation()
	local startLnum = vim.api.nvim_win_get_cursor(0)[1]
	M.indentation("inner", "inner")
	local curLnum = vim.api.nvim_win_get_cursor(0)[1]
	setLinewiseSelection(startLnum, curLnum)
end

-- ISSUE: this function uses `{` and `}` to skip to "blank lines" but according to isBlankLine()
-- "blank lines" includes whitespace-only lines, which `{` and `}` skips over
---outer indentation, expanded until the next blank lines in both directions
---@param scope "inner"|"outer" outer adds a blank, like ip/ap textobjs
function M.greedyOuterIndentation(scope)
	-- select outer indentation
	local invalid = M.indentation("outer", "outer")
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
	local prevLnum
	local nextLnum = isCellBorder(curLnum) and curLnum + 1 or curLnum
	local count = vim.v.count1

	local selectionTailLnum = (getSelectionEndpoints() or {})[1]
	local replaceSelection = selectionTailLnum and curLnum == selectionTailLnum
	local firstLoop = true

	repeat
		while nextLnum < lastLine and not isCellBorder(nextLnum) do
			nextLnum = nextLnum + 1
		end
		if firstLoop then
			firstLoop = false
			local nextInstance = nextLnum - 1 == curLnum and not replaceSelection
			if nextInstance then count = count + 1 end
		end
		count = count - 1
		if count > 0 and nextLnum < lastLine and isCellBorder(nextLnum) then
			nextLnum = nextLnum + 1
		end
	until count <= 0
	prevLnum = nextLnum - 1
	while prevLnum > 1 and not isCellBorder(prevLnum) do
		prevLnum = prevLnum - 1
	end

	-- outer includes bottom cell border
	if scope == "inner" and nextLnum < lastLine then nextLnum = nextLnum - 1 end
	if not replaceSelection then prevLnum = selectionTailLnum end

	setLinewiseSelection(prevLnum, nextLnum)
end

--------------------------------------------------------------------------------
return M

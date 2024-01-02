local M = {}
local u = require("various-textobjs.utils")
local getCursor = vim.api.nvim_win_get_cursor
--------------------------------------------------------------------------------

---@return boolean
local function isVisualMode()
	local modeWithV = vim.fn.mode():find("v")
	return modeWithV ~= nil
end

---@alias pos {[1]: integer, [2]: integer}

---sets the selection for the textobj (characterwise)
---@param startPos pos
---@param endPos pos
local function setSelection(startPos, endPos)
	vim.api.nvim_win_set_cursor(0, startPos)
	if isVisualMode() then
		u.normal("o")
	else
		u.normal("v")
	end
	vim.api.nvim_win_set_cursor(0, endPos)
end

--------------------------------------------------------------------------------

---Seek and select characterwise a text object based on one pattern.
---CAVEAT multi-line-objects are not supported
---@param pattern string lua pattern. REQUIRES two capture groups marking the
---two additions for the outer variant of the textobj. Use an empty capture group
---when there is no difference between inner and outer on that side.
---Essentially, the two capture groups work as lookbehind and lookahead.
---@param scope "inner"|"outer"
---@param lookForwL integer
---@return pos? startPos
---@return pos? endPos
---@nodiscard
local function searchTextobj(pattern, scope, lookForwL)
	local cursorRow, cursorCol = unpack(getCursor(0))
	local lineContent = u.getline(cursorRow)
	local lastLine = vim.api.nvim_buf_line_count(0)
	local beginCol = 0 ---@type number|nil
	local endCol, captureG1, captureG2, noneInStartingLine

	-- first line: check if standing on or in front of textobj
	repeat
		beginCol = beginCol + 1
		beginCol, endCol, captureG1, captureG2 = lineContent:find(pattern, beginCol)
		noneInStartingLine = not beginCol
		local standingOnOrInFront = endCol and endCol > cursorCol
	until standingOnOrInFront or noneInStartingLine

	-- subsequent lines: search full line for first occurrence
	local linesSearched = 0
	if noneInStartingLine then
		while true do
			linesSearched = linesSearched + 1
			if linesSearched > lookForwL or cursorRow + linesSearched > lastLine then return end
			lineContent = u.getline(cursorRow + linesSearched)

			beginCol, endCol, captureG1, captureG2 = lineContent:find(pattern)
			if beginCol then break end
		end
	end

	-- capture groups determine the inner/outer difference
	-- INFO :find() returns integers of the position if the capture group is empty
	if scope == "inner" then
		local frontOuterLen = type(captureG1) ~= "number" and #captureG1 or 0
		local backOuterLen = type(captureG2) ~= "number" and #captureG2 or 0
		beginCol = beginCol + frontOuterLen
		endCol = endCol - backOuterLen
	end

	local startPos = { cursorRow + linesSearched, beginCol - 1 }
	local endPos = { cursorRow + linesSearched, endCol - 1 }
	return startPos, endPos
end

---searches for the position of one or multiple patterns and selects the closest one
---@param patterns string|string[] lua, pattern(s) with the specification from `searchTextobj`
---@param scope "inner"|"outer" true = inner textobj
---@param lookForwL integer
---@return boolean -- whether textobj search was successful
local function selectTextobj(patterns, scope, lookForwL)
	local closestObj

	if type(patterns) == "string" then
		local startPos, endPos = searchTextobj(patterns, scope, lookForwL)
		if startPos and endPos then closestObj = { startPos, endPos } end
	elseif type(patterns) == "table" then
		local closestRow = math.huge
		local shortestDist = math.huge
		local cursorCol = getCursor(0)[2]

		for _, pattern in ipairs(patterns) do
			local startPos, endPos = searchTextobj(pattern, scope, lookForwL)
			if startPos and endPos then
				local row, startCol = unpack(startPos)
				local distance = startCol - cursorCol
				local isCloserInRow = distance < shortestDist

				local cursorOnCurrentObj = (distance < 0)
				local cursorOnClosestObj = (shortestDist < 0)
				if cursorOnCurrentObj and cursorOnClosestObj then
					isCloserInRow = distance > shortestDist
				end

				-- this condition for rows suffices since `searchTextobj` does not
				-- return multi-line-objects
				if (row < closestRow) or (row == closestRow and isCloserInRow) then
					closestRow = row
					shortestDist = distance
					closestObj = { startPos, endPos }
				end
			end
		end
	end

	if closestObj then
		local startPos, endPos = unpack(closestObj)
		setSelection(startPos, endPos)
		return true
	else
		u.notFoundMsg(lookForwL)
		return false
	end
end

--------------------------------------------------------------------------------

---@param scope "inner"|"outer" outer includes trailing -_
function M.subword(scope)
	local pattern = {
		"()%w[%l%d]+([_%- ]?)", -- camelCase or lowercase
		"()%u[%u%d]+([_%- ]?)", -- UPPER_CASE
		"()%d+([_%- ]?)", -- number
	}
	selectTextobj(pattern, scope, 0)
end

---@param lookForwL integer
function M.toNextClosingBracket(lookForwL)
	local pattern = "().([]})])"

	local _, endPos = searchTextobj(pattern, "inner", lookForwL)
	if not endPos then
		u.notFoundMsg(lookForwL)
		return
	end
	local startPos = getCursor(0)

	setSelection(startPos, endPos)
end

---@param lookForwL integer
function M.toNextQuotationMark(lookForwL)
	-- char before quote must not be escape char. Using `vim.opt.quoteescape` on
	-- the off-chance that the user has customized this.
	local quoteEscape = vim.opt_local.quoteescape:get() -- default: \
	local pattern = ([[()[^%s](["'`])]]):format(quoteEscape)

	local _, endPos = searchTextobj(pattern, "inner", lookForwL)
	if not endPos then
		u.notFoundMsg(lookForwL)
		return
	end
	local startPos = getCursor(0)

	setSelection(startPos, endPos)
end

---@param scope "inner"|"outer"
---@param lookForwL integer
function M.anyQuote(scope, lookForwL)
	-- INFO char before quote must not be escape char. Using `vim.opt.quoteescape` on
	-- the off-chance that the user has customized this.
	local escape = vim.opt_local.quoteescape:get() -- default: \
	local patterns = {
		('([^%s]").-[^%s](")'):format(escape, escape), -- ""
		("([^%s]').-[^%s](')"):format(escape, escape), -- ''
		("([^%s]`).-[^%s](`)"):format(escape, escape), -- ``
	}

	selectTextobj(patterns, scope, lookForwL)

	-- pattern includes one extra character to account for an escape character,
	-- so we need to move to the right to factor that in
	if scope == "outer" then u.normal("ol") end
end

---@param scope "inner"|"outer"
---@param lookForwL integer
function M.anyBracket(scope, lookForwL)
	local patterns = {
		"(%().-(%))", -- ()
		"(%[).-(%])", -- []
		"({).-(})", -- {}
	}
	selectTextobj(patterns, scope, lookForwL)
end

---near end of the line, ignoring trailing whitespace
---(relevant for markdown, where you normally add a -space after the `.` ending a sentence.)
function M.nearEoL()
	local pattern = "()%S(%S%s*)$"

	local _, endPos = searchTextobj(pattern, "inner", 0)
	if not endPos then return end
	local startPos = getCursor(0)

	setSelection(startPos, endPos)
end

---current line (but characterwise)
---@param scope "inner"|"outer" outer includes indentation and trailing spaces
function M.lineCharacterwise(scope)
	local pattern = "^(%s*).*(%s*)$"
	selectTextobj(pattern, scope, 0)
end

---similar to https://github.com/andrewferrier/textobj-diagnostic.nvim
---requires builtin LSP
---@param lookForwL integer
function M.diagnostic(lookForwL)
	-- INFO for whatever reason, diagnostic line numbers and the end column (but
	-- not the start column) are all off-by-one…

	-- HACK if cursor is standing on a diagnostic, get_prev() will return that
	-- diagnostic *BUT* only if the cursor is not on the first character of the
	-- diagnostic, since the columns checked seem to be off-by-one as well m(
	-- Therefore counteracted by temporarily moving the cursor
	u.normal("l")
	local prevD = vim.diagnostic.get_prev { wrap = false }
	u.normal("h")

	local nextD = vim.diagnostic.get_next { wrap = false }
	local curStandingOnPrevD = false -- however, if prev diag is covered by or before the cursor has yet to be determined
	local curRow, curCol = unpack(getCursor(0))

	if prevD then
		local curAfterPrevDstart = (curRow == prevD.lnum + 1 and curCol >= prevD.col)
			or (curRow > prevD.lnum + 1)
		local curBeforePrevDend = (curRow == prevD.end_lnum + 1 and curCol <= prevD.end_col - 1)
			or (curRow < prevD.end_lnum)
		curStandingOnPrevD = curAfterPrevDstart and curBeforePrevDend
	end

	local target
	if curStandingOnPrevD then
		target = prevD
	elseif nextD and (curRow + lookForwL > nextD.lnum) then
		target = nextD
	end
	if not target then
		u.notFoundMsg(lookForwL)
		return
	end
	setSelection({ target.lnum + 1, target.col }, { target.end_lnum + 1, target.end_col - 1 })
end

---@param scope "inner"|"outer" inner value excludes trailing commas or semicolons, outer includes them. Both exclude trailing comments.
---@param lookForwL integer
function M.value(scope, lookForwL)
	-- captures value till the end of the line
	-- negative sets and frontier pattern ensure that equality comparators ==, !=
	-- or css pseudo-elements :: are not matched
	local pattern = "(%s*%f[!<>~=:][=:]%s*)[^=:].*()"

	local startPos, endPos = searchTextobj(pattern, scope, lookForwL)
	if not startPos or not endPos then
		u.notFoundMsg(lookForwL)
		return
	end

	-- if value found, remove trailing comment from it
	local curRow = startPos[1]
	local lineContent = u.getline(curRow)
	if vim.bo.commentstring ~= "" then -- JSON has empty commentstring
		local commentPat = vim.bo.commentstring:gsub(" ?%%s.*", "") -- remove placeholder and backside of commentstring
		commentPat = vim.pesc(commentPat) -- escape lua pattern
		commentPat = " *" .. commentPat .. ".*" -- to match till end of line
		lineContent = lineContent:gsub(commentPat, "") -- remove commentstring
	end
	local valueEndCol = #lineContent - 1

	-- inner value = exclude trailing comma/semicolon
	if scope == "inner" and lineContent:find("[,;]$") then valueEndCol = valueEndCol - 1 end

	-- set selection
	endPos[2] = valueEndCol
	setSelection(startPos, endPos)
end

---@param scope "inner"|"outer" outer key includes the `:` or `=` after the key
---@param lookForwL integer
function M.key(scope, lookForwL)
	local pattern = "()%S.-( ?[:=] ?)"
	selectTextobj(pattern, scope, lookForwL)
end

---@param scope "inner"|"outer" inner number consists purely of digits, outer number factors in decimal points and includes minus sign
---@param lookForwL integer
function M.number(scope, lookForwL)
	-- Here two different patterns make more sense, so the inner number can match
	-- before and after the decimal dot. enforcing digital after dot so outer
	-- excludes enumrations.
	local pattern = scope == "inner" and "%d+" or "%-?%d*%.?%d+"
	selectTextobj(pattern, "outer", lookForwL)
end


-- make URL pattern available for external use
M.urlPattern = "%l%l%l-://[A-Za-z0-9_%-/.#%%=?&'@+]+"

---@param lookForwL integer
function M.url(lookForwL)
	-- INFO mastodon URLs contain `@`, neovim docs urls can contain a `'`
	selectTextobj(M.urlPattern, "outer", lookForwL)
end

---see #26
---@param scope "inner"|"outer" inner excludes the leading dot
---@param lookForwL integer
function M.chainMember(scope, lookForwL)
	local pattern = "(%.)[%w_][%a_]*%b()()"
	selectTextobj(pattern, scope, lookForwL)
end

function M.lastChange()
	local changeStartPos = vim.api.nvim_buf_get_mark(0, "[")
	local changeEndPos = vim.api.nvim_buf_get_mark(0, "]")

	if changeStartPos[1] == changeEndPos[1] and changeStartPos[2] == changeEndPos[2] then
		u.notify("Last Change was a deletion operation, aborting.", "warn")
		return
	end

	setSelection(changeStartPos, changeEndPos)
end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---@param scope "inner"|"outer" inner link only includes the link title, outer link includes link, url, and the four brackets.
---@param lookForwL integer
function M.mdlink(scope, lookForwL)
	local pattern = "(%[)[^%]]-(%]%b())"
	selectTextobj(pattern, scope, lookForwL)
end

---@param scope "inner"|"outer" inner selector only includes the content, outer selector includes the type.
---@param lookForwL integer
function M.mdEmphasis(scope, lookForwL)
	local patterns = {}
	for _, leftTag in ipairs({
		"*", "**", "***", "_", "__", "___", "__*", "_**", "**_", "*__"
	}) do
		local rightTag = string.reverse(leftTag)
		local escLeftTag = vim.pesc(leftTag)
		local escRightTag = vim.pesc(rightTag)
		table.insert(patterns, ("^(%s)[^\\_*](%s)"):format(escLeftTag, escRightTag))
		table.insert(patterns, ("^(%s)[^\\_*].-[^\\_*](%s)"):format(escLeftTag, escRightTag))
		table.insert(patterns, ("([^\\_*]%s)[^\\_*](%s)"):format(escLeftTag, escRightTag))
		table.insert(patterns, ("([^\\_*]%s)[^\\_*].-[^\\_*](%s)"):format(escLeftTag, escRightTag))
	end

	for _, tag in ipairs({ "==", "~~" }) do
		local escTag = vim.pesc(tag)
		local tagChar = tag:sub(1, 1)
		table.insert(patterns, ("^(%s)[^\\%s](%s)"):format(escTag, tagChar, escTag))
		table.insert(patterns, ("^(%s)[^\\%s].-[^\\%s](%s)"):format(escTag, tagChar, tagChar, escTag))
		table.insert(patterns, ("([^\\%s]%s)[^\\%s](%s)"):format(tagChar, escTag, tagChar, escTag))
		table.insert(patterns, ("([^\\%s]%s)[^\\%s].-[^\\%s](%s)"):format(tagChar, escTag, tagChar, tagChar, escTag))
	end

	selectTextobj(patterns, scope, lookForwL)

	local startCol = vim.fn.getpos("v")[3]
	if startCol ~= 1 then
		-- pattern includes one extra character to account for an escape character,
		-- so we need to move to the right to factor that in
		if scope == "outer" then u.normal("ol") end
	end
end

---@param scope "inner"|"outer" inner double square brackets exclude the brackets themselves
---@param lookForwL integer
function M.doubleSquareBrackets(scope, lookForwL)
	local pattern = "(%[%[).-(%]%])"
	selectTextobj(pattern, scope, lookForwL)
end

---@param scope "inner"|"outer" outer selector includes trailing comma and whitespace
---@param lookForwL integer
function M.cssSelector(scope, lookForwL)
	local pattern = "()[#.][%w-_]+(,? ?)"
	selectTextobj(pattern, scope, lookForwL)
end

---@param scope "inner"|"outer" inner selector is only the value of the attribute inside the quotation marks.
---@param lookForwL integer
function M.htmlAttribute(scope, lookForwL)
	local pattern = [[(%w+=["']).-(["'])]]
	selectTextobj(pattern, scope, lookForwL)
end

---@param scope "inner"|"outer" outer selector includes the front pipe
---@param lookForwL integer
function M.shellPipe(scope, lookForwL)
	local pattern = "()[^|%s][^|]-( ?| ?)"
	selectTextobj(pattern, scope, lookForwL)
end

---INFO this textobj requires the python Treesitter parser
---@param scope "inner"|"outer" inner excludes `"""`
function M.pyTripleQuotes(scope)
	local node = u.getNodeAtCursor()
	if not node then
		u.notify("No node found.", "warn")
		return
	end

	local strNode
	if node:type() == "string" then
		strNode = node
	elseif node:type():find("^string_") or node:type() == "interpolation" then
		strNode = node:parent()
	elseif node:type() == "escape_sequence" or node:parent():type() == "interpolation" then
		strNode = node:parent():parent()
	else
		u.notify("Not on a triple quoted string.", "warn")
		return
	end

	local text = u.getNodeText(strNode)
	local isMultiline = text:find("[\r\n]")

	-- select `string_content` node, which is the inner docstring
	if scope == "inner" then strNode = strNode:child(1) end

	local startRow, startCol, endRow, endCol = vim.treesitter.get_node_range(strNode)

	-- fix various off-by-ones
	startRow = startRow + 1
	endRow = endRow + 1
	if scope == "outer" or not isMultiline then endCol = endCol - 1 end

	-- multiline-inner: exclude line breaks
	if scope == "inner" and isMultiline then
		startCol = 0
		startRow = startRow + 1
		endRow = endRow - 1
		endCol = #vim.api.nvim_buf_get_lines(0, endRow - 1, endRow, false)[1]
	end

	setSelection({ startRow, startCol }, { endRow, endCol })
end

--------------------------------------------------------------------------------
return M

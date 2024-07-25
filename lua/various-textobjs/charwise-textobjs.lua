local M = {}

local u = require("various-textobjs.utils")
local config = require("various-textobjs.config").config
--------------------------------------------------------------------------------

---@return boolean
local function isVisualMode() return vim.fn.mode():find("v") ~= nil end

---@alias pos {[1]: integer, [2]: integer}

---Sets the selection for the textobj (characterwise)
---INFO Exposed for creation of custom textobjs, but subject to change without notice.
---@param startPos pos
---@param endPos pos
function M.setSelection(startPos, endPos)
	u.normal("m`") -- save last position in jumplist
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
---CAVEAT multi-line-objects are not supported.
---INFO Exposed for creation of custom textobjs, but subject to change without notice.
---@param pattern string lua pattern. REQUIRES two capture groups marking the
---two additions for the outer variant of the textobj. Use an empty capture group
---when there is no difference between inner and outer on that side.
---Basically, the two capture groups work similar to lookbehind/lookahead for the
---inner selector.
---@param scope "inner"|"outer"
---@param lookForwL integer
---@return pos? startPos
---@return pos? endPos
---@nodiscard
function M.searchTextobj(pattern, scope, lookForwL)
	local cursorRow, cursorCol = unpack(vim.api.nvim_win_get_cursor(0))
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
---INFO Exposed for creation of custom textobjs, but subject to change without notice.
---@param patterns string|string[] lua, pattern(s) with the specification from `searchTextobj`
---@param scope "inner"|"outer"
---@param lookForwL integer
---@return boolean -- whether textobj search was successful
function M.selectTextobj(patterns, scope, lookForwL)
	local closestObj

	if type(patterns) == "string" then
		local startPos, endPos = M.searchTextobj(patterns, scope, lookForwL)
		if startPos and endPos then closestObj = { startPos, endPos } end
	elseif type(patterns) == "table" then
		local closestRow = math.huge
		local shortestDist = math.huge
		local cursorCol = vim.api.nvim_win_get_cursor(0)[2]

		for _, pattern in ipairs(patterns) do
			local startPos, endPos = M.searchTextobj(pattern, scope, lookForwL)
			if startPos and endPos then
				local row, startCol = unpack(startPos)
				local distance = startCol - cursorCol
				local isCloserInRow = distance < shortestDist

				-- INFO Here, we cannot simply use the absolute value of the distance.
				-- If the cursor is standing on a big textobj A, and there is a
				-- second textobj B which starts right after the cursor, A has a
				-- high negative distance, and B has a small positive distance.
				-- Using simply the absolute value to determine the which obj is the
				-- closer one would then result in B being selected, even though the
				-- idiomatic behavior in vim is to always select an obj the cursor
				-- is standing on before seeking forward for a textobj.
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
		M.setSelection(startPos, endPos)
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
	M.selectTextobj(pattern, scope, 0)
end

function M.toNextClosingBracket()
	local pattern = "().([]})])"

	local _, endPos = M.searchTextobj(pattern, "inner", config.lookForwardSmall)
	if not endPos then
		u.notFoundMsg(config.lookForwardSmall)
		return
	end
	local startPos = vim.api.nvim_win_get_cursor(0)

	M.setSelection(startPos, endPos)
end

function M.toNextQuotationMark()
	-- char before quote must not be escape char. Using `vim.opt.quoteescape` on
	-- the off-chance that the user has customized this.
	local quoteEscape = vim.opt_local.quoteescape:get() -- default: \
	local pattern = ([[()[^%s](["'`])]]):format(quoteEscape)

	local _, endPos = M.searchTextobj(pattern, "inner", config.lookForwardSmall)
	if not endPos then
		u.notFoundMsg(config.lookForwardSmall)
		return
	end
	local startPos = vim.api.nvim_win_get_cursor(0)

	M.setSelection(startPos, endPos)
end

---@param scope "inner"|"outer"
function M.anyQuote(scope)
	-- INFO char before quote must not be escape char. Using `vim.opt.quoteescape` on
	-- the off-chance that the user has customized this.
	local escape = vim.opt_local.quoteescape:get() -- default: \
	local patterns = {
		('^(").-[^%s](")'):format(escape), -- ""
		("^(').-[^%s](')"):format(escape), -- ''
		("^(`).-[^%s](`)"):format(escape), -- ``
		('([^%s]").-[^%s](")'):format(escape, escape), -- ""
		("([^%s]').-[^%s](')"):format(escape, escape), -- ''
		("([^%s]`).-[^%s](`)"):format(escape, escape), -- ``
	}

	M.selectTextobj(patterns, scope, config.lookForwardSmall)

	-- pattern accounts for escape char, so move to right to account for that
	local isAtStart = vim.api.nvim_win_get_cursor(0)[2] == 1
	if scope == "outer" and not isAtStart then u.normal("ol") end
end

---@param scope "inner"|"outer"
function M.anyBracket(scope)
	local patterns = {
		"(%().-(%))", -- ()
		"(%[).-(%])", -- []
		"({).-(})", -- {}
	}
	M.selectTextobj(patterns, scope, config.lookForwardSmall)
end

---near end of the line, ignoring trailing whitespace
---(relevant for markdown, where you normally add a -space after the `.` ending a sentence.)
function M.nearEoL()
	local pattern = "().(%S%s*)$"

	local _, endPos = M.searchTextobj(pattern, "inner", 0)
	if not endPos then return end
	local startPos = vim.api.nvim_win_get_cursor(0)

	M.setSelection(startPos, endPos)
end

---current line (but characterwise)
---@param scope "inner"|"outer" outer includes indentation and trailing spaces
function M.lineCharacterwise(scope)
	local pattern = "^(%s*).*(%s*)$"
	M.selectTextobj(pattern, scope, 0)
end

---similar to https://github.com/andrewferrier/textobj-diagnostic.nvim
---requires builtin LSP
---@param wrap "wrap"|"nowrap"
function M.diagnostic(wrap)
	-- INFO for whatever reason, diagnostic line numbers and the end column (but
	-- not the start column) are all off-by-one…

	-- HACK if cursor is standing on a diagnostic, get_prev() will return that
	-- diagnostic *BUT* only if the cursor is not on the first character of the
	-- diagnostic, since the columns checked seem to be off-by-one as well m(
	-- Therefore counteracted by temporarily moving the cursor
	u.normal("l")
	local prevD = vim.diagnostic.get_prev { wrap = false }
	u.normal("h")

	local nextD = vim.diagnostic.get_next { wrap = (wrap == "wrap") }
	local curStandingOnPrevD = false -- however, if prev diag is covered by or before the cursor has yet to be determined
	local curRow, curCol = unpack(vim.api.nvim_win_get_cursor(0))

	if prevD then
		local curAfterPrevDstart = (curRow == prevD.lnum + 1 and curCol >= prevD.col)
			or (curRow > prevD.lnum + 1)
		local curBeforePrevDend = (curRow == prevD.end_lnum + 1 and curCol <= prevD.end_col - 1)
			or (curRow < prevD.end_lnum)
		curStandingOnPrevD = curAfterPrevDstart and curBeforePrevDend
	end

	local target = curStandingOnPrevD and prevD or nextD
	if target then
		M.setSelection({ target.lnum + 1, target.col }, { target.end_lnum + 1, target.end_col - 1 })
	else
		u.notify("No diagnostic found.", "warn")
	end
end

---@param scope "inner"|"outer" inner value excludes trailing commas or semicolons, outer includes them. Both exclude trailing comments.
function M.value(scope)
	-- captures value till the end of the line
	-- negative sets and frontier pattern ensure that equality comparators ==, !=
	-- or css pseudo-elements :: are not matched
	local pattern = "(%s*%f[!<>~=:][=:]%s*)[^=:].*()"

	local startPos, endPos = M.searchTextobj(pattern, scope, config.lookForwardSmall)
	if not startPos or not endPos then
		u.notFoundMsg(config.lookForwardSmall)
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
	M.setSelection(startPos, endPos)
end

---@param scope "inner"|"outer" outer key includes the `:` or `=` after the key
function M.key(scope)
	local pattern = "()%S.-( ?[:=] ?)"
	M.selectTextobj(pattern, scope, config.lookForwardSmall)
end

---@param scope "inner"|"outer" inner number consists purely of digits, outer number factors in decimal points and includes minus sign
function M.number(scope)
	-- Here two different patterns make more sense, so the inner number can match
	-- before and after the decimal dot. enforcing digital after dot so outer
	-- excludes enumrations.
	local pattern = scope == "inner" and "%d+" or "%-?%d*%.?%d+"
	M.selectTextobj(pattern, "outer", config.lookForwardSmall)
end

-- make URL pattern available for external use
-- INFO mastodon URLs contain `@`, neovim docs urls can contain a `'`, special
-- urls like https://docs.rs/regex/1.*/regex/#syntax can have a `*`
M.urlPattern = "%l%l%l-://[A-Za-z0-9_%-/.#%%=?&'@+*:]+"
function M.url() M.selectTextobj(M.urlPattern, "outer", config.lookForwardBig) end

---see #26
---@param scope "inner"|"outer" inner excludes the leading dot
function M.chainMember(scope)
	local patterns = {
		"([:.])[%w_][%a_]-%b()()", -- with call
		"([:.])[%w_][%a_]*()", -- without call
	}
	M.selectTextobj(patterns, scope, config.lookForwardSmall)
end

function M.lastChange()
	local changeStartPos = vim.api.nvim_buf_get_mark(0, "[")
	local changeEndPos = vim.api.nvim_buf_get_mark(0, "]")

	if changeStartPos[1] == changeEndPos[1] and changeStartPos[2] == changeEndPos[2] then
		u.notify("Last Change was a deletion operation, aborting.", "warn")
		return
	end

	M.setSelection(changeStartPos, changeEndPos)
end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---@param scope "inner"|"outer" inner link only includes the link title, outer link includes link, url, and the four brackets.
function M.mdlink(scope)
	local pattern = "(%[)[^%]]-(%]%b())"
	M.selectTextobj(pattern, scope, config.lookForwardSmall)
end

---@param scope "inner"|"outer" inner selector only includes the content, outer selector includes the type.
function M.mdEmphasis(scope)
	-- CAVEAT this still has a few edge cases with escaped markup, will need a
	-- treesitter object to reliably account for that.
	local patterns = {
		"([^\\]%*%*?).-[^\\](%*%*?)", -- * or **
		"([^\\]__?).-[^\\](__?)", -- _ or __
		"([^\\]==).-[^\\](==)", -- ==
		"([^\\]~~).-[^\\](~~)", -- ~~
		"(^%*%*?).-[^\\](%*%*?)", -- * or **
		"(^__?).-[^\\](__?)", -- _ or __
		"(^==).-[^\\](==)", -- ==
		"(^~~).-[^\\](~~)", -- ~~
	}
	M.selectTextobj(patterns, scope, config.lookForwardSmall)

	-- pattern accounts for escape char, so move to right to account for that
	local isAtStart = vim.api.nvim_win_get_cursor(0)[2] == 1
	if scope == "outer" and not isAtStart then u.normal("ol") end
end

---@param scope "inner"|"outer" inner selector excludes the brackets themselves
function M.doubleSquareBrackets(scope)
	local pattern = "(%[%[).-(%]%])"
	M.selectTextobj(pattern, scope, config.lookForwardSmall)
end

---@param scope "inner"|"outer" outer selector includes trailing comma and whitespace
function M.cssSelector(scope)
	local pattern = "()[#.][%w-_]+(,? ?)"
	M.selectTextobj(pattern, scope, config.lookForwardSmall)
end

---@param scope "inner"|"outer" inner selector is only the value of the attribute inside the quotation marks.
function M.htmlAttribute(scope)
	local pattern = [[(%w+=["']).-(["'])]]
	M.selectTextobj(pattern, scope, config.lookForwardSmall)
end

---@param scope "inner"|"outer" outer selector includes the pipe
function M.shellPipe(scope)
	local patterns = {
		"()[^|%s][^|]-( ?| ?)", -- trailing pipe, 1st char non-space to exclude indentation
		"( ?| ?)[^|]*()", -- leading pipe
	}
	M.selectTextobj(patterns, scope, config.lookForwardSmall)
end

---@param scope "inner"|"outer" inner selector only affects the color value
function M.cssColor(scope)
	local pattern = {
		"(#)" .. ("%x"):rep(6) .. "()", -- #123456
		"(#)" .. ("%x"):rep(3) .. "()", -- #123
		"(hsl%()[%%%d,./deg ]-(%))", -- hsl(123, 23, 23) or hsl(123deg, 123%, 123% / 100)
		"(rgb%()[%d,./ ]-(%))", -- rgb(123, 123, 123) or rgb(50%, 50%, 50%)
	}
	M.selectTextobj(pattern, scope, config.lookForwardSmall)
end

---INFO this textobj requires the python Treesitter parser
---@param scope "inner"|"outer" inner selector excludes the `"""`
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

	---@cast strNode TSNode
	local text = u.getNodeText(strNode)
	local isMultiline = text:find("[\r\n]")

	---@cast strNode TSNode
	local startRow, startCol, endRow, endCol = vim.treesitter.get_node_range(strNode)

	if scope == "inner" then
		local startNode = strNode:child(1) or strNode
		local endNode = strNode:child(strNode:child_count() - 2) or strNode
		startRow, startCol, _, _ = vim.treesitter.get_node_range(startNode)
		_, _, endRow, endCol = vim.treesitter.get_node_range(endNode)
	end

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

	M.setSelection({ startRow, startCol }, { endRow, endCol })
end

--------------------------------------------------------------------------------
return M

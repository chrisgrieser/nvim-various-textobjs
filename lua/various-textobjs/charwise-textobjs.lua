local M = {}
local fn = vim.fn
local bo = vim.bo
local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

---@return boolean
local function isVisualMode()
	local modeWithV = vim.fn.mode():find("v")
	return modeWithV ~= nil
end

---sets the selection for the textobj (characterwise)
---@class pos number[]
---@param startpos pos
---@param endpos pos
local function setSelection(startpos, endpos)
	u.setCursor(0, startpos)
	if isVisualMode() then
		u.normal("o")
	else
		u.normal("v")
	end
	u.setCursor(0, endpos)
end

--------------------------------------------------------------------------------

---Seek and select characterwise text object based on pattern.
---@param pattern string lua pattern. REQUIRED two capture groups marking the two additions for the outer variant of the textobj. Use an empty capture group when there is no difference between inner and outer on that side. (Essentially, the two capture groups work as lookbehind and lookahead.)
---@param inner boolean true = inner textobj
---@param lookForwL integer number of lines to look forward for the textobj
---@return boolean whether textobj search was successful
local function searchTextobj(pattern, inner, lookForwL)
	local cursorRow, cursorCol = unpack(u.getCursor(0))
	local lineContent = u.getline(cursorRow)
	local lastLine = fn.line("$")
	local beginCol = 0
	local endCol, captureG1, captureG2, noneInStartingLine

	-- first line: check if standing on or in front of textobj
	repeat
		beginCol = beginCol + 1
		beginCol, endCol, captureG1, captureG2 = lineContent:find(pattern, beginCol)
		noneInStartingLine = not beginCol
		local standingOnOrInFront = endCol and endCol > cursorCol
	until standingOnOrInFront or noneInStartingLine

	-- subsequent lines: search full line for first occurrence
	local i = 0
	if noneInStartingLine then
		while true do
			i = i + 1
			if i > lookForwL or cursorRow + i > lastLine then
				u.notFoundMsg(lookForwL)
				return false
			end
			lineContent = u.getline(cursorRow + i)

			beginCol, endCol, captureG1, captureG2 = lineContent:find(pattern)
			if beginCol then break end
		end
	end

	-- capture groups determine the inner/outer difference
	-- INFO :find() returns integers of the position if the capture group is empty
	if inner then
		local frontOuterLen = type(captureG1) ~= "number" and #captureG1 or 0
		local backOuterLen = type(captureG2) ~= "number" and #captureG2 or 0
		beginCol = beginCol + frontOuterLen
		endCol = endCol - backOuterLen
	end

	setSelection({ cursorRow + i, beginCol - 1 }, { cursorRow + i, endCol - 1 })
	return true
end

--------------------------------------------------------------------------------
---Subword
---@param inner boolean outer includes trailing -_
function M.subword(inner)
	local pattern = "()%w[%l%d]+([_- ]?)"

	-- adjust pattern when word under cursor is all uppercase to handle
	-- subwords of SCREAMING_SNAKE_CASE variables
	local upperCaseWord = fn.expand("<cword>") == fn.expand("<cword>"):upper()
	if upperCaseWord then pattern = "()[%u%d]+([_-]?)" end

	-- forward looking results in unexpected behavior for subword
	searchTextobj(pattern, inner, 0)
end

---till next closing bracket
---@param lookForwL integer number of lines to look forward for the textobj
function M.toNextClosingBracket(lookForwL)
	-- since `searchTextobj` just select the next closing bracket, we save the
	-- current cursor position and then afterwards move backwards. While this is
	-- a less straightforward approach, this allows us to re-use `searchTextobj`
	-- instead of re-implementing the forward-searching algorithm
	local startingPosition = u.getCursor(0)

	local pattern = "().([]})])"
	searchTextobj(pattern, true, lookForwL)

	u.setCursor(0, startingPosition)
end

---near end of the line, ignoring trailing whitespace (relevant for markdown)
function M.nearEoL()
	if not isVisualMode() then u.normal("v") end
	u.normal("$")

	-- loop ensures trailing whitespace is not counted
	local curRow = fn.line(".")
	local lineContent = u.getline(curRow)
	local lastCol = fn.col("$")
	repeat
		u.normal("h")
		lastCol = lastCol - 1
		local lastChar = lineContent:sub(lastCol, lastCol)
	until not lastChar:find("%s") or lastCol == 1

	u.normal("h")
end

---current line (but characterwise)
---@param inner boolean outer includes indentation and trailing spaces
function M.lineCharacterwise(inner)
	if fn.col("$") == 1 then -- edge case: empty line
		return
	end

	if not isVisualMode() then u.normal("v") end
	if inner then
		u.normal("g_o^")
	else
		u.normal("$ho0")
	end
end

---similar to https://github.com/andrewferrier/textobj-diagnostic.nvim
---requires builtin LSP
---@param lookForwL integer number of lines to look forward for the textobj
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
	local curRow, curCol = unpack(u.getCursor(0))

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
	else
		u.notFoundMsg(lookForwL)
		return
	end
	setSelection({ target.lnum + 1, target.col }, { target.end_lnum + 1, target.end_col - 1 })
end

---@param inner boolean inner value excludes trailing commas or semicolons, outer includes them. Both exclude trailing comments.
---@param lookForwL integer number of lines to look forward for the textobj
function M.value(inner, lookForwL)
	-- captures value till the end of the line
	-- negative sets to not find equality comparators == or css pseudo-elements ::
	local pattern = "([^=:][=:] ?)[^=:].*()"

	local valueFound = searchTextobj(pattern, true, lookForwL)
	if not valueFound then return end

	-- if value found, remove trailing comment from it
	local curRow = fn.line(".")
	local lineContent = u.getline(curRow)
	if bo.commentstring ~= "" then -- JSON has empty commentstring
		local commentPat = bo.commentstring:gsub(" ?%%s.*", "") -- remove placeholder and backside of commentstring
		commentPat = vim.pesc(commentPat) -- escape lua pattern
		commentPat = " *" .. commentPat .. ".*" -- to match till end of line
		lineContent = lineContent:gsub(commentPat, "") -- remove commentstring
	end
	local valueEndCol = #lineContent - 1

	-- inner value = exclude trailing comma/semicolon
	if inner and lineContent:find("[,;]$") then valueEndCol = valueEndCol - 1 end

	u.setCursor(0, { curRow, valueEndCol })
end

---@param inner boolean outer key includes the `:` or `=` after the key
---@param lookForwL integer number of lines to look forward for the textobj
function M.key(inner, lookForwL)
	local pattern = "(%s*).-( ?[:=] ?)"

	local valueFound = searchTextobj(pattern, inner, lookForwL)
	if not valueFound then return end

	-- 1st capture is included for the outer obj, but we don't want it
	if not inner then
		local curRow = fn.line(".")
		local leadingWhitespace = u.getline(curRow):find("[^%s]") - 1
		u.normal("o")
		u.setCursor(0, { curRow, leadingWhitespace })
	end
end

---number textobj
---@param inner boolean inner number consists purely of digits, outer number factors in decimal points and includes minus sign
---@param lookForwL integer number of lines to look forward for the textobj
function M.number(inner, lookForwL)
	-- here two different patterns make more sense, so the inner number can match
	-- before and after the decimal dot. enforcing digital after dot so outer
	-- excludes enumrations.
	local pattern = inner and "%d+" or "%-?%d*%.?%d+"
	searchTextobj(pattern, false, lookForwL)
	vim.notify("number textobj is deprecated, use the corresponding treesitter-textobject instead.")
end

---URL textobj
---@param lookForwL integer number of lines to look forward for the textobj
function M.url(lookForwL)
	-- TODO match other urls (file://, ftp://, etc.) as well. Requires searchTextobj()
	-- being able to handle multiple patterns, though, since lua pattern do not
	-- have optional groups. Think of a way to implement this without making
	-- searchTextobj unnecessarily complex for other methods
	local pattern = "https?://[A-Za-z0-9_%-/.#%%=?&]+"
	searchTextobj(pattern, false, lookForwL)
end

---field which a call
---see also https://github.com/chrisgrieser/nvim-various-textobjs/issues/26
---@param inner boolean inner excludes the leading dot
---@param lookForwL integer number of lines to look forward for the textobj
function M.chainMember(inner, lookForwL)
	local pattern = "(%.)[%w_][%a_]*%b()()"
	searchTextobj(pattern, inner, lookForwL)
end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---md links textobj
---@param inner boolean inner link only includes the link title, outer link includes link, url, and the four brackets.
---@param lookForwL integer number of lines to look forward for the textobj
function M.mdlink(inner, lookForwL)
	local pattern = "(%[)"
		.. "[^]]-" -- first character in lua pattern set being `]` escapes it
		.. "(%]%b())"
	searchTextobj(pattern, inner, lookForwL)
end

---double square brackets
---@param inner boolean inner double square brackets exclude the brackets themselves
---@param lookForwL integer number of lines to look forward for the textobj
function M.doubleSquareBrackets(inner, lookForwL)
	local pattern = "(%[%[).-(%]%])"
	searchTextobj(pattern, inner, lookForwL)
end

---JS Regex
---@param inner boolean inner regex excludes the slashes (and flags)
---@param lookForwL integer number of lines to look forward for the textobj
function M.jsRegex(inner, lookForwL)
	-- [^\] to not match escaped slash in regex, %l* to match flags
	local pattern = [[(/).-[^\](/%l*)]]
	searchTextobj(pattern, inner, lookForwL)
	vim.notify("jsRegex textobj is deprecated, use corresponding the treesitter-textobject instead.")
end

---CSS Selector Textobj
---@param inner boolean outer selector includes trailing comma and whitespace
---@param lookForwL integer number of lines to look forward for the textobj
function M.cssSelector(inner, lookForwL)
	local pattern = "()[#.][%w-_]+(,? ?)"
	searchTextobj(pattern, inner, lookForwL)
end

---HTML/XML Attribute Textobj
---@param inner boolean inner selector is only the value of the attribute inside the quotation marks.
---@param lookForwL integer number of lines to look forward for the textobj
function M.htmlAttribute(inner, lookForwL)
	local pattern = '(%w+=").-(")'
	searchTextobj(pattern, inner, lookForwL)
end

---Shell Pipe Textobj
---@param inner boolean outer selector includes the front pipe
---@param lookForwL integer number of lines to look forward for the textobj
function M.shellPipe(inner, lookForwL)
	local pattern = "(| ?)[^|]+()"
	searchTextobj(pattern, inner, lookForwL)
end

--------------------------------------------------------------------------------
return M

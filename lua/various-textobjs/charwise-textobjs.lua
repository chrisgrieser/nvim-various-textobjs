local M = {}
local u = require("various-textobjs.utils")
local getCursor = vim.api.nvim_win_get_cursor
--------------------------------------------------------------------------------

---@param scope "inner"|"outer" outer includes trailing -_
function M.subword(scope)
	local pattern = {
		"()%w[%l%d]+([_%- ]?)", -- camelCase or lowercase
		"()%u[%u%d]+([_%- ]?)", -- UPPER_CASE
		"()%d+([_%- ]?)", -- number
	}
	u.selectTextobj(pattern, scope, 0)
end

---@param lookForwL integer
function M.toNextClosingBracket(lookForwL)
	local pattern = "().([]})])"

	local _, endPos = u.searchTextobj(pattern, "inner", lookForwL)
	if not endPos then
		u.notFoundMsg(lookForwL)
		return
	end
	local startPos = getCursor(0)

	u.setSelection(startPos, endPos)
end

---@param lookForwL integer
function M.toNextQuotationMark(lookForwL)
	-- char before quote must not be escape char. Using `vim.opt.quoteescape` on
	-- the off-chance that the user has customized this.
	local quoteEscape = vim.opt_local.quoteescape:get() -- default: \
	local pattern = ([[()[^%s](["'`])]]):format(quoteEscape)

	local _, endPos = u.searchTextobj(pattern, "inner", lookForwL)
	if not endPos then
		u.notFoundMsg(lookForwL)
		return
	end
	local startPos = getCursor(0)

	u.setSelection(startPos, endPos)
end

---@param scope "inner"|"outer"
---@param lookForwL integer
function M.anyQuote(scope, lookForwL)
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

	u.selectTextobj(patterns, scope, lookForwL)

	-- pattern accounts for escape char, so move to right to account for that
	local isAtStart = vim.api.nvim_win_get_cursor(0)[2] == 1
	if scope == "outer" and not isAtStart then u.normal("ol") end
end

---@param scope "inner"|"outer"
---@param lookForwL integer
function M.anyBracket(scope, lookForwL)
	local patterns = {
		"(%().-(%))", -- ()
		"(%[).-(%])", -- []
		"({).-(})", -- {}
	}
	u.selectTextobj(patterns, scope, lookForwL)
end

---near end of the line, ignoring trailing whitespace
---(relevant for markdown, where you normally add a -space after the `.` ending a sentence.)
function M.nearEoL()
	local pattern = "().(%S%s*)$"

	local _, endPos = u.searchTextobj(pattern, "inner", 0)
	if not endPos then return end
	local startPos = getCursor(0)

	u.setSelection(startPos, endPos)
end

---current line (but characterwise)
---@param scope "inner"|"outer" outer includes indentation and trailing spaces
function M.lineCharacterwise(scope)
	local pattern = "^(%s*).*(%s*)$"
	u.selectTextobj(pattern, scope, 0)
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
	u.setSelection({ target.lnum + 1, target.col }, { target.end_lnum + 1, target.end_col - 1 })
end

---@param scope "inner"|"outer" inner value excludes trailing commas or semicolons, outer includes them. Both exclude trailing comments.
---@param lookForwL integer
function M.value(scope, lookForwL)
	-- captures value till the end of the line
	-- negative sets and frontier pattern ensure that equality comparators ==, !=
	-- or css pseudo-elements :: are not matched
	local pattern = "(%s*%f[!<>~=:][=:]%s*)[^=:].*()"

	local startPos, endPos = u.searchTextobj(pattern, scope, lookForwL)
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
	u.setSelection(startPos, endPos)
end

---@param scope "inner"|"outer" outer key includes the `:` or `=` after the key
---@param lookForwL integer
function M.key(scope, lookForwL)
	local pattern = "()%S.-( ?[:=] ?)"
	u.selectTextobj(pattern, scope, lookForwL)
end

---@param scope "inner"|"outer" inner number consists purely of digits, outer number factors in decimal points and includes minus sign
---@param lookForwL integer
function M.number(scope, lookForwL)
	-- Here two different patterns make more sense, so the inner number can match
	-- before and after the decimal dot. enforcing digital after dot so outer
	-- excludes enumrations.
	local pattern = scope == "inner" and "%d+" or "%-?%d*%.?%d+"
	u.selectTextobj(pattern, "outer", lookForwL)
end

-- make URL pattern available for external use
M.urlPattern = "%l%l%l-://[A-Za-z0-9_%-/.#%%=?&'@+]+"

---@param lookForwL integer
function M.url(lookForwL)
	-- INFO mastodon URLs contain `@`, neovim docs urls can contain a `'`
	u.selectTextobj(M.urlPattern, "outer", lookForwL)
end

---see #26
---@param scope "inner"|"outer" inner excludes the leading dot
---@param lookForwL integer
function M.chainMember(scope, lookForwL)
	local pattern = "(%.)[%w_][%a_]*%b()()"
	u.selectTextobj(pattern, scope, lookForwL)
end

function M.lastChange()
	local changeStartPos = vim.api.nvim_buf_get_mark(0, "[")
	local changeEndPos = vim.api.nvim_buf_get_mark(0, "]")

	if changeStartPos[1] == changeEndPos[1] and changeStartPos[2] == changeEndPos[2] then
		u.notify("Last Change was a deletion operation, aborting.", "warn")
		return
	end

	u.setSelection(changeStartPos, changeEndPos)
end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---@param scope "inner"|"outer" inner link only includes the link title, outer link includes link, url, and the four brackets.
---@param lookForwL integer
function M.mdlink(scope, lookForwL)
	local pattern = "(%[)[^%]]-(%]%b())"
	u.selectTextobj(pattern, scope, lookForwL)
end

---@param scope "inner"|"outer" inner selector only includes the content, outer selector includes the type.
---@param lookForwL integer
function M.mdEmphasis(scope, lookForwL)
	-- CAVEAT this still has a few edge cases with escaped markup, will need a
	-- treesitter object to reliably account for that.
	local patterns = {
		"([^\\]%*%*?).-[^\\](%*%*?)", -- * or **
		"([^\\]__?).-[^\\](__?)",     -- _ or __
		"([^\\]==).-[^\\](==)",       -- ==
		"([^\\]~~).-[^\\](~~)",       -- ~~
		"(^%*%*?).-[^\\](%*%*?)",     -- * or **
		"(^__?).-[^\\](__?)",         -- _ or __
		"(^==).-[^\\](==)",           -- ==
		"(^~~).-[^\\](~~)",           -- ~~
	}
	u.selectTextobj(patterns, scope, lookForwL)

	-- pattern accounts for escape char, so move to right to account for that
	local isAtStart = vim.api.nvim_win_get_cursor(0)[2] == 1
	if scope == "outer" and not isAtStart then u.normal("ol") end
end

---@param scope "inner"|"outer" inner double square brackets exclude the brackets themselves
---@param lookForwL integer
function M.doubleSquareBrackets(scope, lookForwL)
	local pattern = "(%[%[).-(%]%])"
	u.selectTextobj(pattern, scope, lookForwL)
end

---@param scope "inner"|"outer" outer selector includes trailing comma and whitespace
---@param lookForwL integer
function M.cssSelector(scope, lookForwL)
	local pattern = "()[#.][%w-_]+(,? ?)"
	u.selectTextobj(pattern, scope, lookForwL)
end

---@param scope "inner"|"outer" inner selector is only the value of the attribute inside the quotation marks.
---@param lookForwL integer
function M.htmlAttribute(scope, lookForwL)
	local pattern = [[(%w+=["']).-(["'])]]
	u.selectTextobj(pattern, scope, lookForwL)
end

---@param scope "inner"|"outer" outer selector includes the front pipe
---@param lookForwL integer
function M.shellPipe(scope, lookForwL)
	local pattern = "()[^|%s][^|]-( ?| ?)"
	u.selectTextobj(pattern, scope, lookForwL)
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

	u.setSelection({ startRow, startCol }, { endRow, endCol })
end

--------------------------------------------------------------------------------
return M

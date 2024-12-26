local M = {}
local core = require("various-textobjs.textobjs.charwise.core")
local u = require("various-textobjs.utils")

--------------------------------------------------------------------------------

-- Warn in case user tries to call a textobj that doesn't exist.
-- (Only needed in the module for `charwise` text objects, since it is the catch
-- all for the `__index` redirect from this plugin's main `init.lua`.)
setmetatable(M, {
	__index = function(_, key)
		return function()
			local msg = ("There is no text object called `%s`.\n\n"):format(key)
				.. "Make sure it exists in the list of text objects, and that you haven't misspelled it."
			u.warn(msg)
		end
	end,
})

---@return integer
---@nodiscard
local function smallForward() return require("various-textobjs.config").config.forwardLooking.small end

--------------------------------------------------------------------------------

---@param scope "inner"|"outer"
function M.subword(scope)
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
	startCol, endCol = startCol + 1, endCol + 1 -- adjust for lua indexing
	local charBefore = line:sub(startCol - 1, startCol - 1)
	local lastChar = line:sub(endCol, endCol)
	local charAfter = line:sub(endCol + 1, endCol + 1)

	-- The outer pattern checks for subwords that with potentially trailing
	-- `_-`, however, if the subword is the last segment of a word, there is
	-- potentially also a leading `_-` which should be included (see #83).

	-- Checking for those with patterns is not possible, since subwords without
	-- any trailing/leading chars are always considered the closest (and thus
	-- prioritized by `selectClosestTextobj`), even though the usage expectation
	-- is that `subword` should be more greedy. Thus, we check if we are on the
	-- last part of a snake_cased word, and if so, add the leading `_-` to the
	-- selection.
	local onLastSnakeCasePart = charBefore:find("[_-]") and not lastChar:find("[_-]")
	if scope == "outer" and onLastSnakeCasePart then
		-- `o`: to start of selection, `h`: select char before `o`: back to end
		u.normal("oho")
	end

	-- When deleting the start of a camelCased word, the result should still be
	-- camelCased and not PascalCased (see #113).
	if require("various-textobjs.config").config.textobjs.subword.noCamelToPascalCase then
		local wasCamelCased = vim.fn.expand("<cword>"):find("%l%u") ~= nil
		local followedByPascalCase = charAfter:find("%u")
		local isStartOfWord = charBefore:find("%W") or charBefore == ""
		local isDeletion = vim.v.operator == "d"
		if wasCamelCased and followedByPascalCase and isStartOfWord and isDeletion then
			local updatedLine = line:sub(1, endCol) .. charAfter:lower() .. line:sub(endCol + 2)
			vim.api.nvim_buf_set_lines(0, row - 1, row, false, { updatedLine })
		end
	end
end

function M.toNextClosingBracket()
	local pattern = "().([]})])"
	local row, _, endCol = core.getTextobjPos(pattern, "inner", smallForward())
	core.selectFromCursorTo({ row, endCol }, smallForward())
end

function M.toNextQuotationMark()
	local pattern = [[()[^\](["'`])]]
	local row, _, endCol = core.getTextobjPos(pattern, "inner", smallForward())
	core.selectFromCursorTo({ row, endCol }, smallForward())
end

---@param scope "inner"|"outer"
function M.anyQuote(scope)
	-- INFO
	-- `%f[\"]` is the lua frontier pattern, and effectively used as a negative
	-- lookbehind, that is ensuring that the previous character may not be a `\`
	local patterns = {
		['""'] = [[(%f[\"]").-(%f[\"]")]],
		["''"] = [[(%f[\']').-(%f[\']')]],
		["``"] = [[(%f[\`]`).-(%f[\`]`)]],
	}
	core.selectClosestTextobj(patterns, scope, smallForward())
end

---@param scope "inner"|"outer"
function M.anyBracket(scope)
	local patterns = {
		["()"] = "(%().-(%))",
		["[]"] = "(%[).-(%])",
		["{}"] = "({).-(})",
	}
	core.selectClosestTextobj(patterns, scope, smallForward())
end

---near end of the line, ignoring trailing whitespace
---(relevant for markdown, where you normally add a -space after the `.` ending a sentence.)
function M.nearEoL()
	local pattern = "().(%S%s*)$"
	local row, _, endCol = core.getTextobjPos(pattern, "inner", 0)
	core.selectFromCursorTo({ row, endCol }, smallForward())
end

---current line, but characterwise
---@param scope "inner"|"outer" outer includes indentation and trailing spaces
function M.lineCharacterwise(scope)
	local pattern = "^(%s*).-(%s*)$" -- use `.-` so inner obj does not match trailing spaces
	core.selectClosestTextobj(pattern, scope, smallForward())
end

function M.diagnostic(oldWrapSetting)
	-- DEPRECATION (2024-12-03)
	if oldWrapSetting ~= nil then
		local msg =
			'`.diagnostic()` does not use a "wrap" argument anymore. Use the config `textobjs.diagnostic.wrap` instead.'
		u.warn(msg)
	end

	local wrap = require("various-textobjs.config").config.textobjs.diagnostic.wrap

	-- HACK if cursor is standing on a diagnostic, get_prev() will return that
	-- diagnostic *BUT* only if the cursor is not on the first character of the
	-- diagnostic, since the columns checked seem to be off-by-one as well m(
	-- Therefore counteracted by temporarily moving the cursor
	u.normal("l")
	local prevD = vim.diagnostic.get_prev { wrap = false }
	u.normal("h")

	local nextD = vim.diagnostic.get_next { wrap = wrap }
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
		core.setSelection(
			{ target.lnum + 1, target.col },
			{ target.end_lnum + 1, target.end_col - 1 }
		)
	else
		u.notFoundMsg("No diagnostic found.")
	end
end

---@param scope "inner"|"outer" inner value excludes trailing commas or semicolons, outer includes them. Both exclude trailing comments.
function M.value(scope)
	-- captures value till the end of the line
	-- negative sets and frontier pattern ensure that equality comparators ==, !=
	-- or css pseudo-elements :: are not matched
	local pattern = "(%s*%f[!<>~=:][=:]%s*)[^=:].*()"

	local row, startCol, _ = core.getTextobjPos(pattern, scope, smallForward())
	if not (row and startCol) then
		u.notFoundMsg(smallForward())
		return
	end

	-- if value found, remove trailing comment from it
	local lineContent = u.getline(row)
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
	core.setSelection({ row, startCol }, { row, valueEndCol })
end

---@param scope "inner"|"outer" outer key includes the `:` or `=` after the key
function M.key(scope)
	local pattern = "()%S.-( ?[:=] ?)"
	core.selectClosestTextobj(pattern, scope, smallForward())
end

---@param scope "inner"|"outer" inner number consists purely of digits, outer number factors in decimal points and includes minus sign
function M.number(scope)
	-- Here two different patterns make more sense, so the inner number can match
	-- before and after the decimal dot. enforcing digital after dot so outer
	-- excludes enumrations.
	local pattern = scope == "inner" and "%d+" or "%-?%d*%.?%d+"
	core.selectClosestTextobj(pattern, "outer", smallForward())
end

function M.url()
	local urlPatterns = require("various-textobjs.config").config.textobjs.url.patterns
	local bigForward = require("various-textobjs.config").config.forwardLooking.big
	core.selectClosestTextobj(urlPatterns, "outer", bigForward)
end

---@param scope "inner"|"outer" inner excludes the leading dot
function M.chainMember(scope)
	-- make without-call lose ties, so call is always included
	local patterns = {
		tieloser_leadingWithoutCall = "()[%w_][%w_]*([:.])",
		leadingWithCall = "()[%w_][%w_]*%b()([:.])",
		tieloser_followingWithoutCall = "([:.])[%w_][%w_]*()",
		followingWithCall = "([:.])[%w_][%w_]*%b()()",
	}
	core.selectClosestTextobj(patterns, scope, smallForward())
end

function M.lastChange()
	local changeStartPos = vim.api.nvim_buf_get_mark(0, "[")
	local changeEndPos = vim.api.nvim_buf_get_mark(0, "]")

	if changeStartPos[1] == changeEndPos[1] and changeStartPos[2] == changeEndPos[2] then
		u.warn("Last change was a deletion operation, aborting.")
		return
	end

	core.setSelection(changeStartPos, changeEndPos)
end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---@param scope "inner"|"outer" inner link only includes the link title, outer link includes link, url, and the four brackets.
function M.mdLink(scope)
	local pattern = "(%[)[^%]]-(%]%b())"
	core.selectClosestTextobj(pattern, scope, smallForward())
end

-- DEPRECATION (2024-12-04), changed for consistency with other objects
function M.mdlink() u.warn("`.mdlink()` is deprecated. Use `.mdLink()` instead (uses capital L).") end

---@param scope "inner"|"outer" inner selector only includes the content, outer selector includes the type.
function M.mdEmphasis(scope)
	-- CAVEAT this still has a few edge cases with escaped markup, will need a
	-- treesitter object to reliably account for that.
	local patterns = {
		["**?"] = "([^\\]%*%*?).-[^\\](%*%*?)",
		["__?"] = "([^\\]__?).-[^\\](__?)",
		["=="] = "([^\\]==).-[^\\](==)",
		["~~"] = "([^\\]~~).-[^\\](~~)",
		["**? (start)"] = "(^%*%*?).-[^\\](%*%*?)",
		["__? (start)"] = "(^__?).-[^\\](__?)",
		["== (start)"] = "(^==).-[^\\](==)",
		["~~ (start)"] = "(^~~).-[^\\](~~)",
	}
	core.selectClosestTextobj(patterns, scope, smallForward())

	-- pattern accounts for escape char, so move to right to account for that
	local isAtStart = vim.api.nvim_win_get_cursor(0)[2] == 1
	if scope == "outer" and not isAtStart then u.normal("ol") end
end

---@param scope "inner"|"outer" inner selector excludes the brackets themselves
function M.doubleSquareBrackets(scope)
	local pattern = "(%[%[).-(%]%])"
	core.selectClosestTextobj(pattern, scope, smallForward())
end

---@param scope "inner"|"outer" outer selector includes trailing comma and whitespace
function M.cssSelector(scope)
	local pattern = "()[#.][%w-_]+(,? ?)"
	core.selectClosestTextobj(pattern, scope, smallForward())
end

---@param scope "inner"|"outer" inner selector is only the value of the attribute inside the quotation marks.
function M.htmlAttribute(scope)
	local pattern = {
		['""'] = '([%w-]+=").-(")',
		["''"] = "([%w-]+=').-(')",
	}
	core.selectClosestTextobj(pattern, scope, smallForward())
end

---@param scope "inner"|"outer" outer selector includes the pipe
function M.shellPipe(scope)
	local patterns = {
		trailingPipe = "()[^|%s][^|]-( ?| ?)", -- 1st char non-space to exclude indentation
		leadingPipe = "( ?| ?)[^|]*()",
	}
	core.selectClosestTextobj(patterns, scope, smallForward())
end

---@param scope "inner"|"outer" inner selector only affects the color value
function M.cssColor(scope)
	local pattern = {
		["#123456"] = "(#)" .. ("%x"):rep(6) .. "()",
		["#123"] = "(#)" .. ("%x"):rep(3) .. "()",
		["hsl(123, 23%, 23%)"] = "(hsla?%()[%%%d,./deg ]-(%))", -- optionally with `deg`/`%`
		["rgb(123, 23, 23)"] = "(rgba?%()[%d,./ ]-(%))", -- optionally with `%`
	}
	core.selectClosestTextobj(pattern, scope, smallForward())
end

--------------------------------------------------------------------------------
return M

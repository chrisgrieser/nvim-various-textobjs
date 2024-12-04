local M = {}

local u = require("various-textobjs.utils")
local config = require("various-textobjs.config").config
--------------------------------------------------------------------------------

---@return boolean
---@nodiscard
local function isVisualMode() return vim.fn.mode():find("v") ~= nil end

---Sets the selection for the textobj (characterwise)
---@param startPos { [1]: integer, [2]: integer }
---@param endPos { [1]: integer, [2]: integer }
function M.setSelection(startPos, endPos)
	u.normal("m`") -- save last position in jumplist
	vim.api.nvim_win_set_cursor(0, startPos)
	u.normal(isVisualMode() and "o" or "v")
	vim.api.nvim_win_set_cursor(0, endPos)
end

--------------------------------------------------------------------------------

-- INFO The following function are exposed for creation of custom textobjs, but
-- subject to change without notice.

---Seek and select characterwise a text object based on one pattern.
---CAVEAT multi-line-objects are not supported.
---@param pattern string lua pattern. REQUIRES two capture groups marking the
---two additions for the outer variant of the textobj. Use an empty capture group
---when there is no difference between inner and outer on that side.
---Basically, the two capture groups work similar to lookbehind/lookahead for the
---inner selector.
---@param scope "inner"|"outer"
---@param lookForwL integer
---@return integer? startCol
---@return integer? endCol
---@return integer? row
---@nodiscard
function M.getTextobjPos(pattern, scope, lookForwL)
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

	beginCol = beginCol - 1
	endCol = endCol - 1
	local row = cursorRow + linesSearched
	return row, beginCol, endCol
end

---Searches for the position of one or multiple patterns and selects the closest one
---@param patterns string|table<string, string> lua, pattern(s) with the specification from `searchTextobj`
---@param scope "inner"|"outer"
---@param lookForwL integer
---@return integer? row
---@return integer? startCol
---@return integer? endCol
function M.selectClosestTextobj(patterns, scope, lookForwL)
	local enableLogging = false -- DEBUG
	local objLogging = {}

	-- initialized with values to always loose comparisons
	local closest = { row = math.huge, distance = math.huge, tieloser = true, cursorOnObj = false }

	-- get text object
	if type(patterns) == "string" then
		closest.row, closest.startCol, closest.endCol = M.getTextobjPos(patterns, scope, lookForwL)
	elseif type(patterns) == "table" then
		local cursorCol = vim.api.nvim_win_get_cursor(0)[2]

		for patternName, pattern in pairs(patterns) do
			local cur = {}
			cur.row, cur.startCol, cur.endCol = M.getTextobjPos(pattern, scope, lookForwL)
			if cur.row and cur.startCol and cur.endCol then
				cur.distance = cur.startCol - cursorCol
				cur.tieloser = patternName:find("tieloser") ~= nil
				cur.cursorOnObj = cur.distance <= 0

				-- INFO Here, we cannot simply use the absolute value of the distance.
				-- If the cursor is standing on a big textobj A, and there is a
				-- second textobj B which starts right after the cursor, A has a
				-- high negative distance, and B has a small positive distance.
				-- Using simply the absolute value to determine which obj is the
				-- closer one would then result in B being selected, even though the
				-- idiomatic behavior in vim is to always select an obj the cursor
				-- is standing on before seeking forward for a textobj.
				local closerInRow = cur.distance < closest.distance
				if cur.cursorOnObj and closest.cursorOnObj then
					closerInRow = cur.distance > closest.distance
					-- tieloser = when both objects enclose the cursor, the tieloser
					-- loses even when it is closer
					if closest.tieloser and not cur.tieloser then closerInRow = true end
					if not closest.tieloser and cur.tieloser then closerInRow = false end
				end

				if (cur.row < closest.row) or (cur.row == closest.row and closerInRow) then
					closest = cur
				end

				-- stylua: ignore
				objLogging[patternName] = { cur.startCol, cur.endCol, row = cur.row, distance = cur.distance, tieloser = cur.tieloser, cursorOnObj = cur.cursorOnObj }
			end
		end
	end

	if not (closest.row and closest.startCol and closest.endCol) then
		u.notFoundMsg(lookForwL)
		return
	end

	-- set selection & log
	M.setSelection({ closest.row, closest.startCol }, { closest.row, closest.endCol })
	if enableLogging then
		local textobj = debug.getinfo(3, "n").name
		objLogging._closest = closest.patternName
		vim.notify(vim.inspect(objLogging), nil, { ft = "lua", title = scope .. " " .. textobj })
	end
	return closest.row, closest.startCol, closest.endCol
end

--------------------------------------------------------------------------------

---@param scope "inner"|"outer"
function M.subword(scope)
	local patterns = {
		camelOrLowercase = "()%a[%l%d]+([_-]?)",
		UPPER_CASE = "()%u[%u%d]+([_-]?)",
		number = "()%d+([_-]?)",
		tieloser_singleChar = "()%a([_-]?)", -- e.g., "x" in "xSide" or "sideX" (see #75)
	}
	local row, startCol, endCol = M.selectClosestTextobj(patterns, scope, 0)
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
	local row, _, endCol = M.getTextobjPos(pattern, "inner", config.forwardLooking.small)
	if not (row and endCol) then
		u.notFoundMsg(config.forwardLooking.small)
		return
	end
	local cursorPos = vim.api.nvim_win_get_cursor(0)

	M.setSelection(cursorPos, { row, endCol })
end

function M.toNextQuotationMark()
	-- char before quote must not be escape char. Using `vim.opt.quoteescape` on
	-- the off-chance that the user has customized this.
	local quoteEscape = vim.opt_local.quoteescape:get() -- default: \
	local pattern = ([[()[^%s](["'`])]]):format(quoteEscape)

	local row, _, endCol = M.getTextobjPos(pattern, "inner", config.forwardLooking.small)
	if not (row and endCol) then
		u.notFoundMsg(config.forwardLooking.small)
		return
	end
	local cursorPos = vim.api.nvim_win_get_cursor(0)

	M.setSelection(cursorPos, { row, endCol })
end

---@param scope "inner"|"outer"
function M.anyQuote(scope)
	-- INFO char before quote must not be escape char. Using `vim.opt.quoteescape` on
	-- the off-chance that the user has customized this.
	local escape = vim.opt_local.quoteescape:get() -- default: \
	local patterns = {
		['"" 1'] = ('^(").-[^%s](")'):format(escape),
		["'' 1"] = ("^(').-[^%s](')"):format(escape),
		["`` 1"] = ("^(`).-[^%s](`)"):format(escape),
		['"" 2'] = ('([^%s]").-[^%s](")'):format(escape, escape),
		["'' 2"] = ("([^%s]').-[^%s](')"):format(escape, escape),
		["`` 2"] = ("([^%s]`).-[^%s](`)"):format(escape, escape),
	}

	M.selectClosestTextobj(patterns, scope, config.forwardLooking.small)

	-- pattern accounts for escape char, so move to right to account for that
	local isAtStart = vim.api.nvim_win_get_cursor(0)[2] == 1
	if scope == "outer" and not isAtStart then u.normal("ol") end
end

---@param scope "inner"|"outer"
function M.anyBracket(scope)
	local patterns = {
		["()"] = "(%().-(%))",
		["[]"] = "(%[).-(%])",
		["{}"] = "({).-(})",
	}
	M.selectClosestTextobj(patterns, scope, config.forwardLooking.small)
end

---near end of the line, ignoring trailing whitespace
---(relevant for markdown, where you normally add a -space after the `.` ending a sentence.)
function M.nearEoL()
	local pattern = "().(%S%s*)$"
	local row, _, endCol = M.getTextobjPos(pattern, "inner", 0)
	if not (row and endCol) then return end
	local cursorPos = vim.api.nvim_win_get_cursor(0)

	M.setSelection(cursorPos, { row, endCol })
end

---current line (but characterwise)
---@param scope "inner"|"outer" outer includes indentation and trailing spaces
function M.lineCharacterwise(scope)
	-- FIX being on NUL, see #108 and #109
	-- (Not sure why this only happens for `lineCharacterwise` though…)
	-- `col()` results in "true" char, as it factors in Tabs
	local isOnNUL = #vim.api.nvim_get_current_line() < vim.fn.col(".")
	if isOnNUL then u.normal("g_") end

	local pattern = "^(%s*).-(%s*)$"
	M.selectClosestTextobj(pattern, scope, 0)
end

function M.diagnostic(oldWrapSetting)
	-- DEPRECATION (2024-12-03)
	if oldWrapSetting ~= nil then
		u.warn(
			'`.diagnostic()` does not use "wrap" argument anymore. Use the config `textobjs.diagnostic.wrap` instead.'
		)
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
		M.setSelection({ target.lnum + 1, target.col }, { target.end_lnum + 1, target.end_col - 1 })
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

	local row, startCol, _ = M.getTextobjPos(pattern, scope, config.forwardLooking.small)
	if not (row and startCol) then
		u.notFoundMsg(config.forwardLooking.small)
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
	M.setSelection({ row, startCol }, { row, valueEndCol })
end

---@param scope "inner"|"outer" outer key includes the `:` or `=` after the key
function M.key(scope)
	local pattern = "()%S.-( ?[:=] ?)"
	M.selectClosestTextobj(pattern, scope, config.forwardLooking.small)
end

---@param scope "inner"|"outer" inner number consists purely of digits, outer number factors in decimal points and includes minus sign
function M.number(scope)
	-- Here two different patterns make more sense, so the inner number can match
	-- before and after the decimal dot. enforcing digital after dot so outer
	-- excludes enumrations.
	local pattern = scope == "inner" and "%d+" or "%-?%d*%.?%d+"
	M.selectClosestTextobj(pattern, "outer", config.forwardLooking.small)
end

-- make URL pattern available for external use
-- INFO mastodon URLs contain `@`, neovim docs urls can contain a `'`, special
-- urls like https://docs.rs/regex/1.*/regex/#syntax can have a `*`
M.urlPattern = "%l%l%l-://[A-Za-z0-9_%-/.#%%=?&'@+*:]+"
function M.url() M.selectClosestTextobj(M.urlPattern, "outer", config.forwardLooking.big) end

---@param scope "inner"|"outer" inner excludes the leading dot
function M.chainMember(scope)
	local patterns = {
		leadingWithoutCall = "()[%w_][%w_]-([:.])",
		leadingWithCall = "()[%w_][%w_]-%b()([:.])",
		followingWithoutCall = "([:.])[%w_][%w_]-()",
		followingWithCall = "([:.])[%w_][%w_]-%b()()",
	}
	M.selectClosestTextobj(patterns, scope, config.forwardLooking.small)
end

function M.lastChange()
	local changeStartPos = vim.api.nvim_buf_get_mark(0, "[")
	local changeEndPos = vim.api.nvim_buf_get_mark(0, "]")

	if changeStartPos[1] == changeEndPos[1] and changeStartPos[2] == changeEndPos[2] then
		u.warn("Last change was a deletion operation, aborting.")
		return
	end

	M.setSelection(changeStartPos, changeEndPos)
end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---@param scope "inner"|"outer" inner link only includes the link title, outer link includes link, url, and the four brackets.
function M.mdlink(scope)
	local pattern = "(%[)[^%]]-(%]%b())"
	M.selectClosestTextobj(pattern, scope, config.forwardLooking.small)
end

---@param scope "inner"|"outer" inner selector only includes the content, outer selector includes the type.
function M.mdEmphasis(scope)
	-- CAVEAT this still has a few edge cases with escaped markup, will need a
	-- treesitter object to reliably account for that.
	local patterns = {
		["**? 1"] = "([^\\]%*%*?).-[^\\](%*%*?)",
		["__? 1"] = "([^\\]__?).-[^\\](__?)",
		["== 1"] = "([^\\]==).-[^\\](==)",
		["~~ 1"] = "([^\\]~~).-[^\\](~~)",
		["**? 2"] = "(^%*%*?).-[^\\](%*%*?)",
		["__? 2"] = "(^__?).-[^\\](__?)",
		["== 2"] = "(^==).-[^\\](==)",
		["~~ 2"] = "(^~~).-[^\\](~~)",
	}
	M.selectClosestTextobj(patterns, scope, config.forwardLooking.small)

	-- pattern accounts for escape char, so move to right to account for that
	local isAtStart = vim.api.nvim_win_get_cursor(0)[2] == 1
	if scope == "outer" and not isAtStart then u.normal("ol") end
end

---@param scope "inner"|"outer" inner selector excludes the brackets themselves
function M.doubleSquareBrackets(scope)
	local pattern = "(%[%[).-(%]%])"
	M.selectClosestTextobj(pattern, scope, config.forwardLooking.small)
end

---@param scope "inner"|"outer" outer selector includes trailing comma and whitespace
function M.cssSelector(scope)
	local pattern = "()[#.][%w-_]+(,? ?)"
	M.selectClosestTextobj(pattern, scope, config.forwardLooking.small)
end

---@param scope "inner"|"outer" inner selector is only the value of the attribute inside the quotation marks.
function M.htmlAttribute(scope)
	local pattern = {
		['""'] = '([%w-]+=").-(")',
		["''"] = "([%w-]+=').-(')",
	}
	M.selectClosestTextobj(pattern, scope, config.forwardLooking.small)
end

---@param scope "inner"|"outer" outer selector includes the pipe
function M.shellPipe(scope)
	local patterns = {
		trailingPipe = "()[^|%s][^|]-( ?| ?)", -- 1st char non-space to exclude indentation
		leadingPipe = "( ?| ?)[^|]*()",
	}
	M.selectClosestTextobj(patterns, scope, config.forwardLooking.small)
end

---@param scope "inner"|"outer" inner selector only affects the color value
function M.cssColor(scope)
	local pattern = {
		["#123456"] = "(#)" .. ("%x"):rep(6) .. "()",
		["#123"] = "(#)" .. ("%x"):rep(3) .. "()",
		["hsl(123, 23%, 23%)"] = "(hsla?%()[%%%d,./deg ]-(%))", -- optionally with `deg`/`%`
		["rgb(123, 23, 23)"] = "(rgba?%()[%d,./ ]-(%))", -- optionally with `%`
	}
	M.selectClosestTextobj(pattern, scope, config.forwardLooking.small)
end

--------------------------------------------------------------------------------
return M

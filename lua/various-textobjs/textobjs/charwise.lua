local M = {}
local core = require("various-textobjs.charwise-core")
local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

---@return integer
---@nodiscard
local function smallForward()
	return require("various-textobjs.config.config").config.forwardLooking.small
end

---@return integer
---@nodiscard
local function bigForward()
	return require("various-textobjs.config.config").config.forwardLooking.big
end

--------------------------------------------------------------------------------

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
	-- `(").-(")` would be enough if we were just to check for any quote character.
	--
	-- To handle escaped quotes, we use make use of frontier patterns and handle
	-- various edge cases. `%f[\"]` is the lua frontier pattern, and effectively
	-- used as a negative lookbehind, that is ensuring that the previous
	-- character may not be a `\`.
	local patterns = {
		['"'] = [[(%f[\"]").-(%f[\"]")]],
		["'"] = [[(%f[\']').-(%f[\']')]],
		["`"] = [[(%f[\`]`).-(%f[\`]`)]],

		-- Since the 2nd frontier pattern has to include the quote char, empty
		-- strings such as `""` and strings with an escaped quote as at the end
		-- like `"foo \""` are not matched, thus requiring two extra set of
		-- patterns form them (while keeping the 1st frontier pattern to prevent
		-- the 1st quote from being escaped.)
		['empty "'] = [[(%f[\"]")(")]],
		['escaped quote last "'] = [[(%f[\"]").*\"(")]],
		["empty '"] = [[(%f[\']')(')]],
		["escaped quote last '"] = [[(%f[\']').*\'(')]],
		["empty `"] = [[(%f[\`]`)(`)]],
		["escaped quote last `"] = [[(%f[\`]`).*\`(`)]],
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

---@param scope "inner"|"outer" inner value excludes trailing commas or semicolons, outer includes them. Both exclude trailing comments.
function M.value(scope)
	-- captures value till the end of the line
	-- negative sets and frontier pattern ensure that equality comparators ==, !=
	-- or css pseudo-elements :: are not matched
	local pattern = "(%f[!<>~=:][=:]%s*)[^=:].*()"

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
	local pattern = "()%S.-( ?[:=])"
	core.selectClosestTextobj(pattern, scope, smallForward())
end

---@param scope "inner"|"outer" inner number consists purely of digits, outer number factors in decimal points and includes minus sign
function M.number(scope)
	-- Here two different patterns make more sense, so the inner number can match
	-- before and after the decimal dot. enforcing digital after dot so outer
	-- excludes enumrations.
	local pattern = "%d+" ---@type VariousTextobjs.PatternInput
	if scope == "outer" then
		pattern = {
			-- The outer pattern considers `.` as decimal separators, `_` as
			-- thousand separator, and a potential leading `-` for negative numbers.
			underscoreAsThousandSep = "%-?%d[%d_]*%d%.?%d*",
			noThousandSep = { "%-?%d+%.?%d*", tieloser = true },
		}
	end
	core.selectClosestTextobj(pattern, "outer", smallForward())
end

function M.url()
	local urlPatterns = require("various-textobjs.config.config").config.textobjs.url.patterns
	core.selectClosestTextobj(urlPatterns, "outer", bigForward())
end

---@param scope "inner"|"outer" inner is only the filename
function M.filepath(scope)
	local pattern = {
		unixPath = "([.~]?/?[%w_%-.$/]+/)[%w_%-.]+()",
	}
	core.selectClosestTextobj(pattern, scope, bigForward())
end

---@param scope "inner"|"outer" inner excludes the leading dot
function M.chainMember(scope)
	-- make with-call greedy, so the call of a chainmember is always included
	local patterns = {
		leadingWithoutCall = "()[%w_][%w_]*([:.])",
		leadingWithCall = { "()[%w_][%w_]*%b()([:.])", greedy = true },
		followingWithoutCall = "([:.])[%w_][%w_]*()",
		followingWithCall = { "([:.])[%w_][%w_]*%b()()", greedy = true },
	}
	core.selectClosestTextobj(patterns, scope, smallForward())
end

---@param scope "inner"|"outer" outer includes the comma
function M.argument(scope)
	local patterns = {
		-- CAVEAT patterns will not work with arguments that contain a `()`, to
		-- get those accurately, you will need treeesitter
		leadingComma = [[(,)[%w_."'%]%[]+()]],
		followingComma = [[()[%w_."'%]%[]+(,)]],
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
function M.color(scope)
	local pattern = {
		["#123456"] = "(#)" .. ("%x"):rep(6) .. "()",
		["hsl(123, 23%, 23%)"] = "(hsla?%()[%%%d,./deg ]-(%))", -- optionally with `deg`/`%`
		["rgb(123, 23, 23)"] = "(rgba?%()[%d,./ ]-(%))", -- optionally with `%`
		["ansi-color-e"] = "\\e%[[%d;]+m", -- \e[1;32m or \e[48;5;123m
		["ansi-color-033"] = "\\033%[[%d;]+m",
		["ansi-color-x1b"] = "\\x1b%[[%d;]+m",
	}
	core.selectClosestTextobj(pattern, scope, smallForward())
end

---@deprecated
function M.cssColor(...)
	u.warn("`.cssColor` is deprecated, use `.color`. (Now also supports ansi color codes)")
	M.color(...)
end

--------------------------------------------------------------------------------
return M

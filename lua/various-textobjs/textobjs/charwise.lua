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
	-- `(").-(")` would be enough if we were just to check for any quote char,
	-- but to correctly deal with escaped quotes, empty quotes, while keeping
	-- quotes balanced, we need to employ a more complex system of patterns.
	--
	-- * To ignore escaped quotes, we use of frontier patterns `%f[\"]` as quasi
	--   negative lookbehind, ensuring that the previous character may not be a `\`.
	-- * Caveat A: since the 2nd frontier pattern has to include the quote char,
	--   empty quotes such as `""` and strings with an escaped quote as at the end
	--   like `"foo \""` are not matched.
	-- * Caveat B: In a line like `"" + "foo"`, the pattern `(%f[\"]").-(%f[\"]")`
	--   would match between the 2nd and 3rd quote, but not between the 3rd and 4th
	--   quote.
	-- * To address Caveat B, we also require the first character to not be a
	--   quote. This makes the pattern fully ignore empty quotes, so that in a
	--   line `"" + "foo"`, only the string between the 3rd and 4th quote is
	--   matched. (This requires at least one character between the quotes, but
	--   due to Caveat A, we already never match empty quotes anyway.)
	local patterns = {
		['"'] = [[(%f[\"]")[^"].-(%f[\"]")]],
		["'"] = [[(%f[\']')[^'].-(%f[\']')]],
		["`"] = [[(%f[\`]`)[^`].-(%f[\`]`)]],

		-- * To address Caveat A, we use a two extra sets of patterns to match
		-- empty quote `""` and strings with an escaped quote as last character
		-- like `"foo \""`.
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
		["()"] = "%b()",
		["[]"] = "%b[]",
		["{}"] = "%b{}",
	}
	-- check for smallest match, since we want to find the innermost valid bracket
	core.selectClosestTextobj(patterns, "outer", smallForward(), "smallest-match")

	-- To make use of balanced patterns `%b()`, we cannot use the pattern syntax
	-- from charwise-core, which reliase on the use of two empty capture groups
	-- to determine the inner/outer difference. Thus, we manually remove the
	-- first and last char from the selection, if we are in inner mode.
	local found = vim.fn.mode() == "v"
	if scope == "inner" and found then
		u.normal("holo") -- remove first and last char from selection
	end
end

---near end of the line, ignoring trailing whitespace
---(relevant for markdown, where you normally add a space after the `.` ending a sentence.)
function M.nearEoL()
	local chars = vim.v.count1
	local pattern = "().(" .. ("."):rep(chars - 1) .. "%S%s*)$"
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
		unixPath = "([.~]?/?[%w_%-.$/%%]+/)[%w_%-.%%]+()",
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

---@param scope "inner"|"outer" inner selector excludes the brackets themselves
function M.doubleSquareBrackets(scope)
	local pattern = "(%[%[).-(%]%])"
	core.selectClosestTextobj(pattern, scope, smallForward())
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

--------------------------------------------------------------------------------
return M

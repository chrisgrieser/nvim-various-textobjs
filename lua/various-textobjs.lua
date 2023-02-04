local getCursor = vim.api.nvim_win_get_cursor
local setCursor = vim.api.nvim_win_set_cursor
local bo = vim.bo
local fn = vim.fn

local M = {}
--------------------------------------------------------------------------------
-- CONFIG
-- default value
local lookForwL = 5

local function setupKeymaps()
	local innerOuterMaps = {
		number = "n",
		value = "v",
		key = "k",
		subword = "S", -- lowercase taken for sentence textobj
	}
	local oneMaps = {
		nearEoL = "n",
		restOfParagraph = "r",
		restOfIndentation = "R",
		diagnostic = "!",
		column = "|",
		entireBuffer = "gG", -- G + gg
		url = "L", -- gu, gU, and U would conflict with gugu, gUgU, and gUU. u would conflict with gcu (undo comment)
	}
	local ftMaps = {
		{
			map = { jsRegex = "/" },
			fts = { "javascript", "typescript" },
		},
		{
			map = { mdlink = "l" },
			fts = { "markdown", "toml" },
		},
		{
			map = { mdFencedCodeBlock = "C" },
			fts = { "markdown" },
		},
		{
			map = { doubleSquareBrackets = "D" },
			fts = { "lua", "norg", "sh", "fish", "zsh", "bash", "markdown" },
		},
		{
			map = { cssSelector = "c" },
			fts = { "css", "scss" },
		},
		{
			map = { shellPipe = "P" },
			fts = { "sh", "bash", "zsh", "fish" },
		},
	}
	-----------------------------------------------------------------------------
	local keymap = vim.keymap.set
	for objName, map in pairs(innerOuterMaps) do
		local name = " " .. objName .. " textobj"
		keymap({ "o", "x" }, "a" .. map, function() M[objName](false) end, { desc = "outer" .. name })
		keymap({ "o", "x" }, "i" .. map, function() M[objName](true) end, { desc = "inner" .. name })
	end
	for objName, map in pairs(oneMaps) do
		keymap({ "o", "x" }, map, M[objName], { desc = objName .. " textobj" })
	end
	-- stylua: ignore start
	keymap( { "o", "x" }, "ii" , function() M.indentation(true, true) end, { desc = "inner-inner indentation textobj" })
	keymap( { "o", "x" }, "ai" , function() M.indentation(false, true) end, { desc = "outer-inner indentation textobj" })
	keymap( { "o", "x" }, "iI" , function() M.indentation(true, true) end, { desc = "inner-inner indentation textobj" })
	keymap( { "o", "x" }, "aI" , function() M.indentation(false, false) end, { desc = "outer-outer indentation textobj" })

	vim.api.nvim_create_augroup("VariousTextobjs", {})
	for _, textobj in pairs(ftMaps) do
		vim.api.nvim_create_autocmd("FileType", {
			group = "VariousTextobjs",
			pattern = textobj.fts,
			callback = function()
				for objName, map in pairs(textobj.map) do
					local name = " " .. objName .. " textobj"
					keymap( { "o", "x" }, "a" .. map, function() M[objName](false) end, { desc = "outer" .. name, buffer = true })
					keymap( { "o", "x" }, "i" .. map, function() M[objName](true) end, { desc = "inner" .. name, buffer = true })
				end
			end,
		})
	end
	-- stylua: ignore end
end

---optional setup function
---@param opts table
function M.setup(opts)
	if opts.lookForwardLines then lookForwL = opts.lookForwardLines end
	if opts.useDefaultKeymaps then setupKeymaps() end
end

--------------------------------------------------------------------------------

---runs :normal natively with bang
---@param cmdStr any
local function normal(cmdStr) vim.cmd.normal { cmdStr, bang = true } end

---equivalent to fn.getline(), but using more efficient nvim api
---@param lnum integer
---@return string
local function getline(lnum)
	local lineContent = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)
	return lineContent[1]
end

---@return boolean
local function isVisualMode()
	local modeWithV = fn.mode():find("v")
	return modeWithV ~= nil
end

---@return boolean
local function isVisualLineMode()
	local modeWithV = fn.mode():find("V")
	return modeWithV ~= nil
end

---notification when no textobj could be found
local function notFoundMsg()
	local msg = "Textobject not found within the next " .. tostring(lookForwL) .. " lines."
	if lookForwL == 1 then msg = msg:gsub("s%.$", ".") end -- remove plural s
	vim.notify(msg, vim.log.levels.WARN)
end

---sets the selection for the textobj (characterwise)
---@class pos number[]
---@param startpos pos
---@param endpos pos
local function setSelection(startpos, endpos)
	setCursor(0, startpos)
	if isVisualMode() then
		normal("o")
	else
		normal("v")
	end
	setCursor(0, endpos)
end

---sets the selection for the textobj (linewise)
---@param startline integer
---@param endline integer
local function setLinewiseSelection(startline, endline)
	setCursor(0, { startline, 0 })
	if not isVisualLineMode() then normal("V") end
	normal("o")
	setCursor(0, { endline, 0 })
end

---Seek and select characterwise text object based on pattern.
---@param pattern string lua pattern. Requires two capture groups marking the two additions for the outer variant of the textobj. Use an empty capture group when there is no difference between inner and outer on that side. (Essentially, the two capture groups work as lookbehind and lookahead.)
---@param inner boolean true = inner textobj
---@return boolean whether textobj search was successful
local function searchTextobj(pattern, inner)
	local cursorRow, cursorCol = unpack(getCursor(0))
	local lineContent = getline(cursorRow)
	local lastLine = fn.line("$")
	local beginCol = 0
	local endCol, captureG1, captureG2

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
				notFoundMsg()
				return false
			end
			lineContent = getline(cursorRow + i)

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
--------------------------------------------------------------------------------

--Textobject for the entire buffer content
function M.entireBuffer() setLinewiseSelection(1, fn.line("$")) end

---Subword
---@param inner boolean outer includes trailing -_
function M.subword(inner)
	-- first character restricted to letter, since in most languages also
	-- stipulate that variable names may not start with a digit
	local pattern = "()%a[%l%d]+([_%-]?)"
	searchTextobj(pattern, inner)
end

---near end of the line, ignoring trailing whitespace (relevant for markdown)
function M.nearEoL()
	if not isVisualMode() then normal("v") end
	normal("$")

	-- loop ensures trailing whitespace is not counted, relevant e.g., for markdown
	local curRow = fn.line(".")
	local lineContent = getline(curRow)
	local lastCol = fn.col("$")
	repeat
		normal("h")
		lastCol = lastCol - 1
		local lastChar = lineContent:sub(lastCol, lastCol)
	until not lastChar:find("%s") or lastCol == 1

	normal("h")
end

---rest of paragraph (linewise)
function M.restOfParagraph()
	if not isVisualLineMode() then normal("V") end
	normal("}")
	if fn.line(".") ~= fn.line("$") then normal("k") end -- one up, except on last line
end

---DIAGNOSTIC TEXT OBJECT
---similar to https://github.com/andrewferrier/textobj-diagnostic.nvim
---requires builtin LSP
function M.diagnostic()
	-- INFO for whatever reason, diagnostic line numbers and the end column (but
	-- not the start column) are all off-by-one…

	-- HACK if cursor is standing on a diagnostic, get_prev() will return that
	-- diagnostic *BUT* only if the cursor is not on the first character of the
	-- diagnostic, since the columns checked seem to be off-by-one as well m(
	-- Therefore counteracted by temporarily moving the cursor
	normal("l")
	local prevD = vim.diagnostic.get_prev { wrap = false }
	normal("h")

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
	else
		notFoundMsg()
		return
	end
	setSelection({ target.lnum + 1, target.col }, { target.end_lnum + 1, target.end_col - 1 })
end

-- INDENTATION OBJECT
---indentation textobj, based on https://thevaluable.dev/vim-create-text-objects/
---@param noStartBorder boolean exclude the startline
---@param noEndBorder boolean exclude the endline
function M.indentation(noStartBorder, noEndBorder)
	local function isBlankLine(lineNr)
		local lineContent = getline(lineNr)
		return lineContent:find("^%s*$") == 1
	end

	local indentofStart = fn.indent(fn.line("."))
	if indentofStart == 0 then
		vim.notify("Current line is not indented.", vim.log.levels.WARN)
		return
	end

	local prevLnum = fn.line(".") - 1
	local nextLnum = fn.line(".") + 1
	local lastLine = fn.line("$")

	while isBlankLine(prevLnum) or fn.indent(prevLnum) >= indentofStart do
		if prevLnum < 0 then break end
		prevLnum = prevLnum - 1
	end
	while isBlankLine(nextLnum) or fn.indent(nextLnum) >= indentofStart do
		if nextLnum >= lastLine then break end
		nextLnum = nextLnum + 1
	end

	-- differentiate ai and ii
	if noStartBorder then prevLnum = prevLnum + 1 end
	if noEndBorder then nextLnum = nextLnum - 1 end

	setLinewiseSelection(prevLnum, nextLnum)
end

---from cursor position down all lines with same or higher indentation
function M.restOfIndentation()
	local function isBlankLine(lineNr)
		local lineContent = getline(lineNr)
		return lineContent:find("^%s*$") == 1
	end

	local indentofStart = fn.indent(fn.line("."))
	if indentofStart == 0 then
		vim.notify("Current line is not indented.", vim.log.levels.WARN)
		return
	end

	local curLine = fn.line(".")
	local nextLnum = curLine + 1
	local lastLine = fn.line("$")

	while isBlankLine(nextLnum) or fn.indent(nextLnum) >= indentofStart do
		if nextLnum >= lastLine then break end
		nextLnum = nextLnum + 1
	end

	setLinewiseSelection(curLine, nextLnum - 1)
end

--------------------------------------------------------------------------------

---Column Textobj (blockwise down until indent or shorter line)
function M.column()
	local lastLnum = fn.line("$")
	local nextLnum, cursorCol = unpack(getCursor(0))
	local extraColumns = vim.v.count1 - 1 -- has to be done before running the other :normal commands, since they change v:count

	-- get accurate cursorCol (account for tabs/spaces properly)
	if not bo.expandtab then
		local indentLevel = (fn.indent(".") / bo.tabstop) ---@diagnostic disable-line: param-type-mismatch
		cursorCol = cursorCol + (indentLevel * (bo.tabstop - 1))
	end

	repeat
		nextLnum = nextLnum + 1
		local trueLineLength = #getline(nextLnum):gsub("\t", string.rep(" ", bo.tabstop)) ---@diagnostic disable-line: undefined-field
		local shorterLine = trueLineLength < cursorCol
		local hitsIndent = cursorCol < fn.indent(nextLnum)
		local eof = nextLnum > lastLnum
	until eof or hitsIndent or shorterLine
	nextLnum = nextLnum - 1

	-- start visual block mode
	if not (fn.mode() == "CTRL-V") then vim.cmd.execute([["normal! \<C-v>"]]) end

	normal(nextLnum .. "G")
	if extraColumns > 0 then normal(tostring(extraColumns) .. "l") end
end

---Md Fenced Code Block Textobj
---@param inner boolean inner excludes the backticks
function M.mdFencedCodeBlock(inner)
	local cursorLnum = fn.line(".")
	local codeBlockPattern = "^```%w*$"

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

	if #cbBegin > #cbEnd then table.remove(cbEnd) end -- incomplete codeblock

	-- determine cursor location in a codeblock
	local j = 0
	repeat
		j = j + 1
		if j > #cbBegin then
			notFoundMsg()
			return
		end
		local cursorInBetween = (cbBegin[j] <= cursorLnum) and (cbEnd[j] >= cursorLnum)
		-- seek forward for a codeblock
		local cursorInFront = (cbBegin[j] > cursorLnum) and (cbBegin[j] <= cursorLnum + lookForwL)
	until cursorInBetween or cursorInFront

	local start = cbBegin[j]
	local ending = cbEnd[j]
	if inner then
		start = start + 1
		ending = ending - 1
	end

	setLinewiseSelection(start, ending)
end

---value text object
---@param inner boolean inner value excludes trailing commas or semicolons, outer includes them. Both exclude trailing comments.
function M.value(inner)
	-- captures value till the end of the line
	-- negative sets to not find equality comparators == or css pseudo-elements ::
	local pattern = "([^=:][=:] ?)[^=:].*()"

	local valueFound = searchTextobj(pattern, true)
	if not valueFound then return end

	-- if value found, remove trailing comment from it
	local curRow = fn.line(".")
	local lineContent = getline(curRow)
	if bo.commentstring ~= "" then -- JSON has empty commentstring
		local commentPat = bo.commentstring:gsub(" ?%%s.*", "") -- remove placeholder and backside of commentstring
		commentPat = vim.pesc(commentPat) -- escape lua pattern
		commentPat = " *" .. commentPat .. ".*" -- to match till end of line
		lineContent = lineContent:gsub(commentPat, "") -- remove commentstring
	end
	local valueEndCol = #lineContent - 1

	-- inner value = exclude trailing comma/semicolon
	if inner and lineContent:find("[,;]$") then valueEndCol = valueEndCol - 1 end

	setCursor(0, { curRow, valueEndCol })
end

---key / left side of variable assignment textobj
---@param inner boolean outer key includes the `:` or `=` after the key
function M.key(inner)
	local pattern = "(%s*).-( ?[:=] ?)"

	local valueFound = searchTextobj(pattern, inner)
	if not valueFound then return end

	-- 1st capture is included for the outer obj, but we don't want it
	if not inner then
		local curRow = fn.line(".")
		local leadingWhitespace = getline(curRow):find("[^%s]") - 1
		normal("o")
		setCursor(0, { curRow, leadingWhitespace })
	end
end

---number textobj
---@param inner boolean inner number consists purely of digits, outer number factors in decimal points and includes minus sign
function M.number(inner)
	-- here two different patterns make more sense, so the inner number can match
	-- before and after the decimal dot. enforcing digital after dot so outer
	-- excludes enumrations.
	local pattern = inner and "%d+" or "%-?%d*%.?%d+"
	searchTextobj(pattern, false)
end

---URL textobj
function M.url()
	-- TODO match other urls (file://, ftp://, etc.) as well. Requires searchTextobj()
	-- being able to handle multiple patterns, though, since lua pattern do not
	-- have optional groups. Think of a way to implement this without making
	-- searchTextobj unnecessarily complex for other methods
	local pattern = "https?://[A-Za-z0-9_%-/.#%%=?&]+"
	searchTextobj(pattern, false)
end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---md links textobj
---@param inner boolean inner link only includes the link title, outer link includes link, url, and the four brackets.
function M.mdlink(inner)
	local pattern = "(%[)"
		.. "[^]]-" -- first character in lua pattern set being `]` escapes it
		.. "(%]%b())"
	searchTextobj(pattern, inner)
end

---double square brackets
---@param inner boolean inner double square brackets exclude the brackets themselves
function M.doubleSquareBrackets(inner)
	local pattern = "(%[%[).-(%]%])"
	searchTextobj(pattern, inner)
end

---JS Regex
---@param inner boolean inner regex excludes the slashes (and flags)
function M.jsRegex(inner)
	-- [^\] to not match escaped slash in regex, %l* to match flags
	local pattern = [[(/).-[^\](/%l*)]]
	searchTextobj(pattern, inner)
end

---CSS Selector Textobj
---@param inner boolean outer selector includes trailing comma and whitespace
function M.cssSelector(inner)
	local pattern = "()%.[%w-_]+(,? ?)"
	searchTextobj(pattern, inner)
end

---Shell Pipe Textobj
---@param inner boolean outer selector includes the front pipe
function M.shellPipe(inner)
	local pattern = "(| ?)[^|]+()"
	searchTextobj(pattern, inner)
end

--------------------------------------------------------------------------------
return M

local getCursor = vim.api.nvim_win_get_cursor
local setCursor = vim.api.nvim_win_set_cursor
local bo = vim.bo
local fn = vim.fn
local opt = vim.opt

local M = {}
--------------------------------------------------------------------------------

-- default value
local lookForwardLines = 5

---optional setup function
---@param opts table
function M.setup(opts)
	if opts.lookForwardLines then lookForwardLines = opts.lookForwardLines end
end

--------------------------------------------------------------------------------

---runs :normal natively with bang
---@param cmdStr any
local function normal(cmdStr) vim.cmd.normal { cmdStr, bang = true } end

---@return boolean
local function isVisualMode()
	local modeWithV = fn.mode():find("v")
	return (modeWithV ~= nil and modeWithV ~= false)
end

---@return boolean
local function isVisualLineMode()
	local modeWithV = fn.mode():find("V")
	return (modeWithV ~= nil and modeWithV ~= false)
end

---@class position <integer>[]

---sets the selection for the textobj (characterwise)
---@param startpos position
---@param endpos position
local function setSelection(startpos, endpos)
	setCursor(0, startpos)
	if isVisualMode() then
		normal("o")
	else
		normal("v")
	end
	setCursor(0, endpos)
end

---seek forwards for pattern
---@param pattern string lua pattern
---@param seekFullStartRow? boolean also seek before cursor in starting row. Mostly for value-textobj
---@return integer|nil line pattern was found, or nil if not found
---@return integer beginCol
---@return integer endCol
---@return string capture group from pattern (if provided)
local function seekForward(pattern, seekFullStartRow)
	local startRow, startCol = unpack(getCursor(0))
	if seekFullStartRow then startCol = 1 end
	local lastLine = fn.line("$")
	local lineContent, beginCol, endCol, capture

	local i = -1
	repeat
		i = i + 1

		if i > lookForwardLines or startRow + i > lastLine then
			local msg = "Textobject not found within " .. tostring(lookForwardLines) .. " lines."
			if lookForwardLines == 1 then msg = msg:gsub("s%.$", ".") end
			vim.notify(msg, vim.log.levels.WARN)
			return nil, 0, 0, ""
		end

		lineContent = fn.getline(startRow + i) ---@type string
		beginCol, endCol, capture = lineContent:find(pattern)

		-- after the current row, pattern can occur everywhere in the line
		if i > 0 then startCol = 1 end
		local hasPattern = endCol and (endCol > startCol or endCol == 1)

	until hasPattern

	local findrow = startRow + i
	beginCol = beginCol - 1
	endCol = endCol - 1

	return findrow, beginCol, endCol, capture
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

---Subword (word with "-_" as delimiters)
function M.subword()
	local iskeywBefore = opt.iskeyword:get()
	opt.iskeyword:remove { "_", "-", "." }
	if not isVisualMode() then normal("v") end
	normal("iw")
	opt.iskeyword = iskeywBefore
end

---near end of the line, ignoring trailing whitespace (relevant for markdown)
function M.nearEoL()
	if not isVisualMode() then normal("v") end
	normal("$")

	-- loop ensure trailing whitespace is not counted
	---@diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
	local lineContent = fn.getline(".") ---@type string
	local col = fn.col("$")
	repeat
		normal("h")
		col = col - 1
		local lastChar = lineContent:sub(col, col)
	until not lastChar:find("%s") or col == 1

	normal("h")
end

---rest of paragraph (linewise)
function M.restOfParagraph()
	if not isVisualLineMode() then normal("V") end
	normal("}k")
end

---DIAGNOSTIC TEXT OBJECT
---similar to https://github.com/andrewferrier/textobj-diagnostic.nvim
---requires builtin LSP
function M.diagnostic()
	local diag = vim.diagnostic.get_next { wrap = false }
	if not diag then return end
	local curLine = fn.line(".")
	if curLine + lookForwardLines > diag.lnum then return end
	setSelection({diag.lnum + 1, diag.col}, {diag.end_lnum + 1, diag.end_col})
end

-- INDENTATION OBJECT
---indentation textobj, based on https://thevaluable.dev/vim-create-text-objects/
---@param startBorder boolean
---@param endBorder boolean
function M.indentation(startBorder, endBorder)
	local function isBlankLine(lineNr)
		---@diagnostic disable-next-line: assign-type-mismatch
		local lineContent = fn.getline(lineNr) ---@type string
		return string.find(lineContent, "^%s*$") == 1
	end

	if isBlankLine(fn.line(".")) then return end -- abort on blank line

	local indentofStart = fn.indent(fn.line("."))
	if indentofStart == 0 then return end -- do not select whole file

	local prevLnum = fn.line(".") - 1 -- line before cursor
	while prevLnum > 0 and (isBlankLine(prevLnum) or fn.indent(prevLnum) >= indentofStart) do
		prevLnum = prevLnum - 1
	end
	local nextLnum = fn.line(".") + 1 -- line after cursor
	local lastLine = fn.line("$")
	while nextLnum <= lastLine and (isBlankLine(nextLnum) or fn.indent(nextLnum) >= indentofStart) do
		nextLnum = nextLnum + 1
	end

	-- differentiate ai and ii
	if not startBorder then prevLnum = prevLnum + 1 end
	if not endBorder then nextLnum = nextLnum - 1 end

	-- set selection
	setCursor(0, { prevLnum, 0 })
	if not (isVisualLineMode()) then normal("V") end
	normal("o")
	setCursor(0, { nextLnum, 0 })
end

---VALUE TEXT OBJECT
---@param inner boolean
function M.value(inner)
	local pattern = "[^=:][=:] ?[^=:]" -- negative sets to not find equality comparators == or css pseudo-elements ::

	local row, _, start = seekForward(pattern, true)
	if not row then return end

	-- valueEnd either comment or end of line
	---@diagnostic disable-next-line: assign-type-mismatch
	local lineContent = fn.getline(row) ---@type string
	local comStrPattern = bo.commentstring:gsub(" ?%%s.*", "") -- remove placeholder and backside of commentstring
	comStrPattern = vim.pesc(comStrPattern) -- escape lua pattern

	local isCommentLine = lineContent:find("^%s*" .. comStrPattern)
	if isCommentLine then return end

	local ending, _ = lineContent:find(" ?" .. comStrPattern)
	if not ending or comStrPattern == "" then
		ending = #lineContent - 1
	else
		ending = ending - 2
	end

	-- inner value = without trailing comma/semicolon
	local lastChar = lineContent:sub(ending + 1, ending + 1)
	if inner and lastChar:find("[,;]") then ending = ending - 1 end

	setSelection({row, start}, {row, ending})
end

---number textobj
---@param inner boolean inner number (no decimal or minus-sign)
function M.number(inner)
	local pattern = inner and "%d+" or "%-?%d*%.?%d+"

	local row, start, ending = seekForward(pattern)
	if not row then return end

	setSelection({row, start}, {row, ending})
end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---md links textobj
---@param inner boolean inner or outer link
function M.mdlink(inner)
	local pattern = "(%b[])%b()"

	local row, start, ending, barelink = seekForward(pattern)
	if not row then return end

	if inner then ending = start + #barelink - 3 end

	setSelection({row, start}, {row, ending})
end

---double square brackets
---@param inner boolean inner or outer link
function M.doubleSquareBrackets(inner)
	local pattern = "%[%[.-%]%]"

	local row, start, ending = seekForward(pattern)
	if not row then return end

	if inner then
		start = start + 2
		ending = ending - 2
	end

	setSelection({row, start}, {row, ending})
end

---JS Regex
---@param inner boolean inner regex
function M.jsRegex(inner)
	local pattern = [[/.-[^\]/]] -- to not match escaped slash in regex

	local row, start, ending = seekForward(pattern)
	if not row then return end

	if inner then
		start = start + 1
		ending = ending - 1
	end

	setSelection({row, start}, {row, ending})
end

---CSS Selector Textobj
---@param inner boolean inner selector
function M.cssSelector(inner)
	local pattern = "%.[%w-_]+"

	local row, start, ending = seekForward(pattern)
	if not row then return end

	if inner then start = start + 1 end

	setSelection({row, start}, {row, ending})
end

--------------------------------------------------------------------------------
return M

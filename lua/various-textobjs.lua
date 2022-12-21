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

local function notFoundMsg()
	local msg = "Textobject not found within " .. tostring(lookForwardLines) .. " lines."
	if lookForwardLines == 1 then msg = msg:gsub("s%.$", ".") end -- remove plural s
	vim.notify(msg, vim.log.levels.WARN)
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

---sets the selection for the textobj (linewise)
---@param startline integer
---@param endline integer
local function setLinewiseSelection(startline, endline)
	setCursor(0, { startline, 0 })
	if not (isVisualLineMode()) then normal("V") end
	normal("o")
	setCursor(0, { endline, 0 })
end

--------------------------------------------------------------------------------

---seek forwards for pattern
---@param pattern string lua pattern
---@param seekFullStartRow? boolean also seek before cursor in starting row. Mostly for value-textobj
---@return integer|nil line pattern was found, or nil if not found
---@return integer beginCol
---@return integer endCol
---@return string capture group from pattern (if provided)
---@diagnostic disable: assign-type-mismatch
local function seekForward(pattern, seekFullStartRow)
	local cursorRow, cursorCol = unpack(getCursor(0))
	if seekFullStartRow then cursorCol = 1 end
	local lineContent = fn.getline(cursorRow) ---@type string
	local lastLine = fn.line("$")
	local beginCol = 0
	local endCol, capture

	-- first line: check if standing on or in front of textobj
	repeat
		beginCol, endCol, capture = lineContent:find(pattern, beginCol + 1)
		standingOnOrInFront = endCol and endCol >= cursorCol
	until not beginCol or standingOnOrInFront

	-- subsequent lines: search full line for first occurrence
	local i = 0
	while not standingOnOrInFront do
		i = i + 1
		if i > lookForwardLines or cursorRow + i > lastLine then
			notFoundMsg()
			return nil, 0, 0, ""
		end
		lineContent = fn.getline(cursorRow + i) ---@type string

		beginCol, endCol, capture = lineContent:find(pattern)
		if beginCol then break end
	end

	return cursorRow + i, beginCol - 1, endCol - 1, capture
end
---@diagnostic enable: assign-type-mismatch

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

	-- loop ensures trailing whitespace is not counted, relevant e.g., for markdown
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
	setSelection({ diag.lnum + 1, diag.col }, { diag.end_lnum + 1, diag.end_col })
end

-- INDENTATION OBJECT
---indentation textobj, based on https://thevaluable.dev/vim-create-text-objects/
---@param noStartBorder boolean
---@param noEndBorder boolean
function M.indentation(noStartBorder, noEndBorder)
	local function isBlankLine(lineNr)
		---@diagnostic disable-next-line: assign-type-mismatch
		local lineContent = fn.getline(lineNr) ---@type string
		return string.find(lineContent, "^%s*$") == 1
	end

	local indentofStart = fn.indent(fn.line("."))
	if indentofStart == 0 then return end -- do not select whole file or blank line

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
	if noStartBorder then prevLnum = prevLnum + 1 end
	if noEndBorder then nextLnum = nextLnum - 1 end

	setLinewiseSelection(prevLnum, nextLnum)
end

-- Md Fenced Code Block Textobj
---@param inner boolean
function M.mdFencedCodeBlock(inner)
	local lastLnum = fn.line("$")
	local cursorLnum = fn.line(".")
	local codeBlockPattern = "^```%w*$"

	-- scan buffer for all code blocks
	local cbBegin = {}
	local cbEnd = {}
	for i = 1, lastLnum, 1 do
		---@diagnostic disable: assign-type-mismatch
		local lineContent = fn.getline(i) ---@type string
		if lineContent:find(codeBlockPattern) then
			if #cbBegin == #cbEnd then
				table.insert(cbBegin, i)
			else
				table.insert(cbEnd, i)
			end
		end
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
		local cursorInFront = (cbBegin[j] > cursorLnum) and (cbBegin[j] <= cursorLnum + lookForwardLines)
	until cursorInBetween or cursorInFront

	local start = cbBegin[j]
	local ending = cbEnd[j]
	if inner then
		start = start + 1
		ending = ending - 1
	end

	setLinewiseSelection(start, ending)
end

---VALUE TEXT OBJECT
---@param inner boolean
function M.value(inner)
	local pattern = "[^=:][=:] ?[^=:]" -- negative sets to not find equality comparators == or css pseudo-elements ::

	local row, _, start = seekForward(pattern, true)
	if not row then return end

	---@diagnostic disable-next-line: assign-type-mismatch
	local lineContent = fn.getline(row) ---@type string
	local comStrPattern = bo.commentstring:gsub(" ?%%s.*", "") -- remove placeholder and backside of commentstring
	comStrPattern = vim.pesc(comStrPattern) -- escape lua pattern
	local ending, _ = lineContent:find(" ?" .. comStrPattern)

	local endingIsComment = ending and comStrPattern ~= ""
	if endingIsComment then
		ending = ending - 2
	else
		ending = #lineContent - 1
	end

	-- inner value = without trailing comma/semicolon
	local lastChar = lineContent:sub(ending + 1, ending + 1)
	if inner and lastChar:find("[,;]") then ending = ending - 1 end

	setSelection({ row, start }, { row, ending })
end

---number textobj
---@param inner boolean inner number (no decimal or minus-sign)
function M.number(inner)
	local pattern = inner and "%d+" or "%-?%d*%.?%d+"

	local row, start, ending = seekForward(pattern)
	if not row then return end

	setSelection({ row, start }, { row, ending })
end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---md links textobj
---@param inner boolean inner or outer link
function M.mdlink(inner)
	local pattern = "(%b[])%b()"

	local row, start, ending, barelink = seekForward(pattern)
	if not row then return end

	if inner then
		ending = start + #barelink - 2
		start = start + 1
	end

	setSelection({ row, start }, { row, ending })
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

	setSelection({ row, start }, { row, ending })
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

	setSelection({ row, start }, { row, ending })
end

---CSS Selector Textobj
---@param inner boolean inner selector
function M.cssSelector(inner)
	local pattern = "%.[%w-_]+"

	local row, start, ending = seekForward(pattern)
	if not row then return end

	if inner then start = start + 1 end

	setSelection({ row, start }, { row, ending })
end

--------------------------------------------------------------------------------
return M

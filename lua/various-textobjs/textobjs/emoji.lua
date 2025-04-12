local M = {}
local core = require("various-textobjs.charwise-core")
local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

---Decode one UTF-8 codepoint starting from position `i`
---@param str string UTF-8 encoded string
---@param i number starting byte index
---@return number? cp decoded codepoint
---@return number? nextI The next byte index
local function utf8Decode(str, i)
	local c = str:byte(i)
	if not c then return end

	if c < 0x80 then
		return c, i + 1
	elseif c < 0xE0 then
		local c2 = str:byte(i + 1)
		return ((c % 0x20) * 0x40 + (c2 % 0x40)), i + 2
	elseif c < 0xF0 then
		local c2, c3 = str:byte(i + 1, i + 2)
		return ((c % 0x10) * 0x1000 + (c2 % 0x40) * 0x40 + (c3 % 0x40)), i + 3
	elseif c < 0xF8 then
		local c2, c3, c4 = str:byte(i + 1, i + 3)
		return ((c % 0x08) * 0x40000 + (c2 % 0x40) * 0x1000 + (c3 % 0x40) * 0x40 + (c4 % 0x40)), i + 4
	end
end

---Check if a codepoint is likely an emoji or NerdFont glyph.
---@param cp number Unicode codepoint
---@return boolean
local function isEmoji(cp)
	return (
		(cp >= 0x1F600 and cp <= 0x1F64F) -- Emoticons
		or (cp >= 0x1F300 and cp <= 0x1F5FF) -- Misc Symbols and Pictographs
		or (cp >= 0x1F680 and cp <= 0x1F6FF) -- Transport and Map
		or (cp >= 0x1F900 and cp <= 0x1F9FF) -- Supplemental Symbols and Pictographs
		or (cp >= 0x1FA70 and cp <= 0x1FAFF) -- Extended-A
		or (cp >= 0x2600 and cp <= 0x26FF) -- Misc symbols
		or (cp >= 0x2700 and cp <= 0x27BF) -- Dingbats
		or (cp >= 0xE000 and cp <= 0xF8FF) -- Private Use Area (PUA, where NerdFonts map glyphs)
		or (cp >= 0xF0000 and cp <= 0xFFFFD) -- Supplementary Private Use Area-A
		or (cp >= 0x100000 and cp <= 0x10FFFD) -- Supplementary Private Use Area-B
	)
end

---@param input string
---@param offset number? Optional starting byte index (defaults to 1)
---@return number? startPos The byte index of the start of the emoji
---@return number? endPos The byte index of the end of the emoji
local function findEmoji(input, offset)
	local i = offset or 1
	while i <= #input do
		local cp, nextI = utf8Decode(input, i)
		if not (cp and nextI) then return end
		if isEmoji(cp) then return i, nextI - 1 end
		i = nextI
	end
end

local function getLine(lnum) return vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] end

--------------------------------------------------------------------------------

function M.emoji()
	local lookForw = require("various-textobjs.config.config").config.forwardLooking.small
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local stopRow = math.min(row + lookForw, vim.api.nvim_buf_line_count(0))

	local startPos, endPos
	while true do
		startPos, endPos = findEmoji(getLine(row), col)
		if startPos and endPos then break end
		col = 1 -- for lines after the one with the cursor, search from the start
		row = row + 1
		if row > stopRow then
			u.notFoundMsg(lookForw)
			return
		end
	end

	startPos, endPos = startPos - 1, endPos - 1 -- lua indexing
	core.setSelection({ row, startPos }, { row, endPos })
end

--------------------------------------------------------------------------------
return M

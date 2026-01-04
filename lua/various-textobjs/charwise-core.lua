local M = {}
local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

---Sets the selection for the textobj (characterwise)
---@param startPos { [1]: integer, [2]: integer }
---@param endPos { [1]: integer, [2]: integer }
function M.setSelection(startPos, endPos)
	u.saveJumpToJumplist()

	-- ZERO-WIDTH TEXTOBJECT
	-- These are, for instance, `ci)` on empty brackets like `()`. We copy
	-- vanilla vim's behavior of doing nothing on `d` or `c`, but switch to the
	-- outer object when using `y`. See: https://github.com/echasnovski/mini.nvim/issues/1927
	local isZeroWidthTextobj = startPos[1] >= startPos[2] and startPos[2] > endPos[2]
	if isZeroWidthTextobj and vim.v.operator ~= "y" then
		-- Add single space (without triggering events) and visually select it,
		-- since it's the only way to make `ci)` and `di)` move inside empty
		-- brackets. Idea from `wellle/targets.vim` & `echasnovski/mini.ai`.
		local prevEventignore = vim.o.eventignore
		vim.o.eventignore = "all"
		vim.api.nvim_win_set_cursor(0, startPos)
		vim.cmd([[silent! execute "normal! \<Esc>i \<Esc>v"]])
		vim.o.eventignore = prevEventignore

		local actsOnZeroWidthObr = vim.v.operator == "c"
			or (vim.v.operator == "g@" and vim.o.operatorfunc:find("MiniOperators%.replace"))
			or (vim.v.operator == "g@" and vim.o.operatorfunc:find("substitute"))
		if not actsOnZeroWidthObr then u.warn("Text object has a width of zero; doing nothing.") end
		return
	end

	vim.api.nvim_win_set_cursor(0, startPos)
	u.normal(vim.fn.mode() == "v" and "o" or "v")
	vim.api.nvim_win_set_cursor(0, endPos)
end

---@param endPos { [1]: integer, [2]: integer }
---@param notFoundMsg string|number
function M.selectFromCursorTo(endPos, notFoundMsg)
	if #endPos ~= 2 then
		u.notFoundMsg(notFoundMsg)
		return
	end
	u.saveJumpToJumplist()
	u.normal(vim.fn.mode() == "v" and "o" or "v")
	vim.api.nvim_win_set_cursor(0, endPos)
end

---Seek and select a characterwise textobj based on one pattern.
---`pattern` uses two capture groups to determine the two additions for the
---outer variant of the textobj. Use an empty capture group when there is no
---difference between inner and outer on that side. Basically, the two capture
---groups work similar to lookbehind/lookahead for the inner selector.
---@param pattern string
---@param scope "inner"|"outer"
---@param lookForwLines integer
---@param smallestMatch "smallest-match"|nil
---@return integer? startCol
---@return integer? endCol
---@return integer? row
---@nodiscard
function M.getTextobjPos(pattern, scope, lookForwLines, smallestMatch)
	-- when past the EoL in visual mode, will not find anything in that line
	-- anymore, thus moving back to EoL (see #108 and #109)
	if #vim.api.nvim_get_current_line() < vim.fn.col(".") then u.normal("h") end

	local cursorRow, cursorCol = unpack(vim.api.nvim_win_get_cursor(0))
	local lineContent = u.getline(cursorRow)
	local lastLine = vim.api.nvim_buf_line_count(0)
	local beginCol, endCol, captureG1, captureG2

	-- first line: check if cursor is standing on or in front of textobject
	local nextSearchPos = 1
	while true do
		if lineContent == "" then break end -- GUARD against `""` as `.*` returns non-nil then (#116)
		local start, stop, c1, c2 = lineContent:find(pattern, nextSearchPos)
		if not start then break end -- no match

		-- 1. Normally, we want to stop on the first match found, e.g., `%w+`
		-- should match the largest word and not just a letter. We can then stop
		-- on the first valid object (valid = the cursor stands on or is in front
		-- of it).
		-- 2. For some cases like nested brackets, we need the closest/smallest,
		-- match, potentially nested inside another valid match. For that, we need
		-- to continue after every match, until we have the last (= smallest)
		-- valid match.
		local standingOnOrInFront = stop > cursorCol
		if standingOnOrInFront then
			beginCol, endCol, captureG1, captureG2 = start, stop, c1, c2
			if not smallestMatch then break end
		end
		nextSearchPos = start + 1
	end

	-- subsequent lines: search full line for first occurrence
	local linesSearched = 0
	local notFoundInFirstLine = not beginCol
	if notFoundInFirstLine then
		repeat
			linesSearched = linesSearched + 1
			if linesSearched > lookForwLines or cursorRow + linesSearched > lastLine then return end
			lineContent = u.getline(cursorRow + linesSearched)
			beginCol, endCol, captureG1, captureG2 = lineContent:find(pattern)
		until beginCol
	end

	if scope == "inner" then
		-- capture groups determine the inner/outer difference
		-- `:find()` returns integers of the position if the capture group is
		-- empty, otherwise the content of the capture group
		local frontOuterLen = type(captureG1) == "string" and #captureG1 or 0
		local backOuterLen = type(captureG2) == "string" and #captureG2 or 0
		beginCol = beginCol + frontOuterLen
		endCol = endCol - backOuterLen
	end

	beginCol = beginCol - 1
	endCol = endCol - 1
	local row = cursorRow + linesSearched
	return row, beginCol, endCol
end

--------------------------------------------------------------------------------

---@class (exact) VariousTextobjs.PatternSpec
---@field [1] string the pattern
---@field greedy? boolean when both objs enclose cursor, greedy wins if the distance is the same
---@field tieloser? boolean when both objs enclose cursor, tieloser loses even when it is closer

---@alias VariousTextobjs.PatternInput string|table<string|integer, string|VariousTextobjs.PatternSpec>

---Searches for the position of one or multiple patterns and selects the closest one
---@param patterns VariousTextobjs.PatternInput lua pattern(s) for `getTextobjPos`
---@param scope "inner"|"outer"
---@param lookForwLines integer
---@param smallestMatch "smallest-match"|nil
---@return integer? row -- nil if not found
---@return integer? startCol
---@return integer? endCol
function M.selectClosestTextobj(patterns, scope, lookForwLines, smallestMatch)
	local enableLogging, objLogging = require("various-textobjs.config.config").config.debug, {}
	local cursorCol = vim.api.nvim_win_get_cursor(0)[2]

	-- initialized with values to always lose comparisons
	local closest = { row = math.huge, distance = math.huge, tieloser = true, cursorOnObj = false }

	if type(patterns) == "string" then patterns = { patterns } end

	for patternName, patternSpec in pairs(patterns) do
		local cur = {}
		local pattern = patternSpec
		if type(patternSpec) ~= "string" then -- is PatternSpec instead of string
			pattern = patternSpec[1] ---@cast pattern string ensuring it here
			cur.greedy = patternSpec.greedy
			cur.tieloser = patternSpec.tieloser
		end
		cur.row, cur.startCol, cur.endCol =
			M.getTextobjPos(pattern, scope, lookForwLines, smallestMatch)

		if cur.row and cur.startCol and cur.endCol then
			cur.distance = cur.startCol - cursorCol
			cur.endDistance = cursorCol - cur.endCol
			cur.cursorOnObj = cur.distance <= 0 and cur.endDistance <= 0
			cur.patternName = patternName

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

				-- greedy = when both objects enclose the cursor, the greedy one
				-- wins if the distance is the same
				if cur.distance == closest.distance then
					if cur.greedy and not closest.greedy then closerInRow = true end
					if not cur.greedy and closest.greedy then closerInRow = false end
				end
			end

			if (cur.row < closest.row) or (cur.row == closest.row and closerInRow) then
				closest = cur
			end

			-- stylua: ignore
			if enableLogging then objLogging[patternName] = { cur.startCol, cur.endCol, row = cur.row, distance = cur.distance, tieloser = cur.tieloser, greedy = cur.greedy, cursorOnObj = cur.cursorOnObj, zeroWidthTextobj = cur.startCol > cur.endCol and true or nil } end
		end
	end

	if not (closest.row and closest.startCol and closest.endCol) then
		u.notFoundMsg(lookForwLines)
		return
	end

	if enableLogging then
		local textobj = (debug.getinfo(3, "n") or {}).name or "unknown"
		objLogging._closest = closest.patternName
		local opts = { ft = "lua", title = scope .. " " .. textobj, timeout = false }
		vim.notify(vim.inspect(objLogging), nil, opts)
	end

	M.setSelection({ closest.row, closest.startCol }, { closest.row, closest.endCol })
	return closest.row, closest.startCol, closest.endCol
end

--------------------------------------------------------------------------------
return M

local M = {}
local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

---Sets the selection for the textobj (characterwise)
---@param startPos { [1]: integer, [2]: integer }
---@param endPos { [1]: integer, [2]: integer }
function M.setSelection(startPos, endPos)
	u.saveJumpToJumplist()

	-- GUARD Zero-width textobj
	-- These are, for instance, `ci)` on empty brackets like `()`. We copy
	-- vanilla vim's behavior of doing nothing on `d` or `c`, but switch to the
	-- outer object when using `y`.
	-- see also: https://github.com/echasnovski/mini.nvim/issues/1927
	local isZeroWidthTextobj = startPos[1] >= startPos[2] and startPos[2] > endPos[2]
	if isZeroWidthTextobj and vim.v.operator ~= "y" then
		-- Add single space (without triggering events) and visually select it.
		-- Seems like the only way to make `ci)` and `di)` move inside empty
		-- brackets. Idea from 'wellle/targets.vim' & `echasnovski/mini.ai`.
		local prevEventignore = vim.o.eventignore
		vim.o.eventignore = "all"

		vim.api.nvim_win_set_cursor(0, startPos)
		-- First escape from previously started Visual mode
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
---CAVEAT multi-line-objects are not supported.
---@param pattern string lua pattern. REQUIRES two capture groups marking the
---two additions for the outer variant of the textobj. Use an empty capture group
---when there is no difference between inner and outer on that side. Basically,
---the two capture groups work similar to lookbehind/lookahead for the inner
---selector.
---@param scope "inner"|"outer"
---@param lookForwLines integer
---@return integer? startCol
---@return integer? endCol
---@return integer? row
---@nodiscard
function M.getTextobjPos(pattern, scope, lookForwLines)
	-- when past the EoL in visual mode, will not find anything in that line
	-- anymore, thus moving back to EoL (see #108 and #109)
	if #vim.api.nvim_get_current_line() < vim.fn.col(".") then u.normal("h") end

	local cursorRow, cursorCol = unpack(vim.api.nvim_win_get_cursor(0))
	local lineContent = u.getline(cursorRow)
	local lastLine = vim.api.nvim_buf_line_count(0)
	local endCol = 0 ---@type number|nil
	local beginCol, captureG1, captureG2, in1stLine

	-- first line: check if standing on or in front of textobj
	repeat
		beginCol, endCol, captureG1, captureG2 = lineContent:find(pattern, endCol + 1)
		in1stLine = beginCol and (lineContent ~= "") -- check "" as .* returns non-nil then (#116)
		local standingOnOrInFront = endCol and endCol > cursorCol
	until standingOnOrInFront or not in1stLine

	-- subsequent lines: search full line for first occurrence
	local linesSearched = 0
	if not in1stLine then
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
---@param patterns VariousTextobjs.PatternInput lua pattern(s) for
---`getTextobjPos`; If the pattern starts with `tieloser` the textobj is always
---deprioritzed if the cursor stands on two objects.
---@param scope "inner"|"outer"
---@param lookForwLines integer
---@return integer? row -- only if found
---@return integer? startCol
---@return integer? endCol
function M.selectClosestTextobj(patterns, scope, lookForwLines)
	local enableLogging = require("various-textobjs.config.config").config.debug
	local objLogging = {}

	-- initialized with values to always loose comparisons
	local closest = { row = math.huge, distance = math.huge, tieloser = true, cursorOnObj = false }

	-- get text object
	if type(patterns) == "string" then
		closest.row, closest.startCol, closest.endCol =
			M.getTextobjPos(patterns, scope, lookForwLines)
	elseif type(patterns) == "table" then
		local cursorCol = vim.api.nvim_win_get_cursor(0)[2]

		for patternName, patternSpec in pairs(patterns) do
			local cur = {}
			local pattern = patternSpec
			if type(patternSpec) ~= "string" then -- is PatternSpec instead of string
				pattern = patternSpec[1] ---@cast pattern string ensuring it here
				cur.greedy = patternSpec.greedy
				cur.tieloser = patternSpec.tieloser
			end
			cur.row, cur.startCol, cur.endCol = M.getTextobjPos(pattern, scope, lookForwLines)

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

				if enableLogging then
					objLogging[patternName] = {
						cur.startCol,
						cur.endCol,
						row = cur.row,
						distance = cur.distance,
						tieloser = cur.tieloser,
						cursorOnObj = cur.cursorOnObj,
						zeroWidthTextobj = cur.startCol > cur.endCol and true or nil,
					}
				end
			end
		end
	end

	if not (closest.row and closest.startCol and closest.endCol) then
		u.notFoundMsg(lookForwLines)
		return
	end

	if enableLogging and type(patterns) == "table" then
		local textobj = (debug.getinfo(3, "n") or {}).name or "unknown"
		objLogging._closest = closest.patternName
		vim.notify(
			vim.inspect(objLogging),
			vim.log.levels.DEBUG,
			{ ft = "lua", title = scope .. " " .. textobj }
		)
	end

	M.setSelection({ closest.row, closest.startCol }, { closest.row, closest.endCol })
	return closest.row, closest.startCol, closest.endCol
end

--------------------------------------------------------------------------------
return M

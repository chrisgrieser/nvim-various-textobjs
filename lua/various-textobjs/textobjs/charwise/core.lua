local M = {}
local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

---Sets the selection for the textobj (characterwise)
---@param startPos { [1]: integer, [2]: integer }
---@param endPos { [1]: integer, [2]: integer }
function M.setSelection(startPos, endPos)
	u.saveJumpToJumplist()
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
	local beginCol = 0 ---@type number|nil
	local endCol, captureG1, captureG2, in1stLine

	-- first line: check if standing on or in front of textobj
	repeat
		beginCol, endCol, captureG1, captureG2 = lineContent:find(pattern, beginCol + 1)
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

	-- capture groups determine the inner/outer difference
	-- `:find()` returns integers of the position if the capture group is empty
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
---@param patterns string|table<string, string> lua pattern(s) for
---`getTextobjPos`; If the pattern starts with `tieloser` the textobj is always
---deprioritzed if the cursor stands on two objects.
---@param scope "inner"|"outer"
---@param lookForwLines integer
---@return integer? row
---@return integer? startCol
---@return integer? endCol
function M.selectClosestTextobj(patterns, scope, lookForwLines)
	local enableLogging = require("various-textobjs.config").config.debug
	local objLogging = {}

	-- initialized with values to always loose comparisons
	local closest = { row = math.huge, distance = math.huge, tieloser = true, cursorOnObj = false }

	-- get text object
	if type(patterns) == "string" then
		closest.row, closest.startCol, closest.endCol =
			M.getTextobjPos(patterns, scope, lookForwLines)
	elseif type(patterns) == "table" then
		local cursorCol = vim.api.nvim_win_get_cursor(0)[2]

		for patternName, pattern in pairs(patterns) do
			local cur = {}
			cur.row, cur.startCol, cur.endCol = M.getTextobjPos(pattern, scope, lookForwLines)
			if cur.row and cur.startCol and cur.endCol then
				if type(patternName) == "string" and patternName:find("tieloser") then
					cur.tieloser = true
				end
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
		u.notFoundMsg(lookForwLines)
		return
	end

	-- set selection & log
	M.setSelection({ closest.row, closest.startCol }, { closest.row, closest.endCol })
	if enableLogging and type(patterns) == "table" then
		local textobj = debug.getinfo(3, "n").name
		objLogging._closest = closest.patternName
		vim.notify(
			vim.inspect(objLogging),
			vim.log.levels.DEBUG,
			{ ft = "lua", title = scope .. " " .. textobj }
		)
	end
	return closest.row, closest.startCol, closest.endCol
end

--------------------------------------------------------------------------------
return M

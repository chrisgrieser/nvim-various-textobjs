local M = {}
--------------------------------------------------------------------------------

local getCursor = vim.api.nvim_win_get_cursor

---runs :normal natively with bang
---@param cmdStr any
function M.normal(cmdStr)
	local is08orHigher = vim.version().major > 0 or vim.version().minor > 7
	if is08orHigher then
		vim.cmd.normal { cmdStr, bang = true }
	else
		vim.cmd("normal! " .. cmdStr)
	end
end

---equivalent to fn.getline(), but using more efficient nvim api
---@param lnum integer
---@return string
function M.getline(lnum) return vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1] end

---send notification
---@param msg string
---@param level? "info"|"trace"|"debug"|"warn"|"error"
function M.notify(msg, level)
	if not level then level = "info" end
	vim.notify(msg, vim.log.levels[level:upper()], { title = "nvim-various-textobjs" })
end

---notification when no textobj could be found
---@param lookForwL integer number of lines the plugin tried to look forward
function M.notFoundMsg(lookForwL)
	local msg = "Textobject not found within the next " .. tostring(lookForwL) .. " lines."
	if lookForwL == 1 then msg = msg:gsub("s%.$", ".") end -- remove plural s
	M.notify(msg, "warn")
end

---@return boolean
local function isVisualMode()
	local modeWithV = vim.fn.mode():find("v")
	return modeWithV ~= nil
end

---@alias pos {[1]: integer, [2]: integer}

---sets the selection for the textobj (characterwise)
---@param startPos pos
---@param endPos pos
M.setSelection = function(startPos, endPos)
	vim.api.nvim_win_set_cursor(0, startPos)
	if isVisualMode() then
		M.normal("o")
	else
		M.normal("v")
	end
	vim.api.nvim_win_set_cursor(0, endPos)
end

--------------------------------------------------------------------------------

---Seek and select characterwise a text object based on one pattern.
---CAVEAT multi-line-objects are not supported
---@param pattern string lua pattern. REQUIRES two capture groups marking the
---two additions for the outer variant of the textobj. Use an empty capture group
---when there is no difference between inner and outer on that side.
---Essentially, the two capture groups work as lookbehind and lookahead.
---@param scope "inner"|"outer"
---@param lookForwL integer
---@return pos? startPos
---@return pos? endPos
---@nodiscard
M.searchTextobj = function(pattern, scope, lookForwL)
	local cursorRow, cursorCol = unpack(getCursor(0))
	local lineContent = M.getline(cursorRow)
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
			lineContent = M.getline(cursorRow + linesSearched)

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

	local startPos = { cursorRow + linesSearched, beginCol - 1 }
	local endPos = { cursorRow + linesSearched, endCol - 1 }
	return startPos, endPos
end

---searches for the position of one or multiple patterns and selects the closest one
---@param patterns string|string[] lua, pattern(s) with the specification from `searchTextobj`
---@param scope "inner"|"outer" true = inner textobj
---@param lookForwL integer
---@return boolean -- whether textobj search was successful
M.selectTextobj = function(patterns, scope, lookForwL)
	local closestObj

	if type(patterns) == "string" then
		local startPos, endPos = M.searchTextobj(patterns, scope, lookForwL)
		if startPos and endPos then closestObj = { startPos, endPos } end
	elseif type(patterns) == "table" then
		local closestRow = math.huge
		local shortestDist = math.huge
		local cursorCol = getCursor(0)[2]

		for _, pattern in ipairs(patterns) do
			local startPos, endPos = M.searchTextobj(pattern, scope, lookForwL)
			if startPos and endPos then
				local row, startCol = unpack(startPos)
				local distance = startCol - cursorCol
				local isCloserInRow = distance < shortestDist

				-- INFO Here, we cannot simply use the absolute value of the distance.
				-- If the cursor is standing on a big textobj A, and there is a
				-- second textobj B which starts right after the cursor, A has a
				-- high negative distance, and B has a small positive distance.
				-- Using simply the absolute value to determine the which obj is the
				-- closer one would then result in B being selected, even though the
				-- idiomatic behavior in vim is to always select an obj the cursor
				-- is standing on before seeking forward for a textobj.
				local cursorOnCurrentObj = (distance < 0)
				local cursorOnClosestObj = (shortestDist < 0)
				if cursorOnCurrentObj and cursorOnClosestObj then
					isCloserInRow = distance > shortestDist
				end

				-- this condition for rows suffices since `searchTextobj` does not
				-- return multi-line-objects
				if (row < closestRow) or (row == closestRow and isCloserInRow) then
					closestRow = row
					shortestDist = distance
					closestObj = { startPos, endPos }
				end
			end
		end
	end

	if closestObj then
		local startPos, endPos = unpack(closestObj)
		M.setSelection(startPos, endPos)
		return true
	else
		M.notFoundMsg(lookForwL)
		return false
	end
end

--------------------------------------------------------------------------------
-- TREESITTER UTILS

---get node at cursor and validate that the user has at least nvim 0.9
---@return nil|TSNode nil if no node or nvim version too old
function M.getNodeAtCursor()
	if vim.treesitter.get_node == nil then
		M.notify("This textobj requires least nvim 0.9.", "warn")
		return nil
	end
	return vim.treesitter.get_node()
end

---@param node TSNode
---@return string
function M.getNodeText(node) return vim.treesitter.get_node_text(node, 0) end

--------------------------------------------------------------------------------
return M

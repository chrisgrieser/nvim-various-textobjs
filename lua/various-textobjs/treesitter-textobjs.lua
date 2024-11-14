local M = {}
local u = require("various-textobjs.utils")
local charwise = require("various-textobjs.charwise-textobjs")
--------------------------------------------------------------------------------

---INFO this textobj requires the python Treesitter parser
---@param scope "inner"|"outer" inner selector excludes the `"""`
function M.pyTripleQuotes(scope)
	-- GUARD
	if vim.treesitter.get_node == nil then
		u.notify("This textobj requires least nvim 0.9.", "warn")
		return
	end
	local node = vim.treesitter.get_node()
	if not node then
		u.notify("No node found.", "notfound")
		return
	end

	-- get right node
	local strNode
	if node:type() == "string" then
		strNode = node
	elseif node:type():find("^string_") or node:type() == "interpolation" then
		strNode = node:parent()
	elseif
		node:type() == "escape_sequence"
		or (node:parent() and node:parent():type() == "interpolation")
	then
		strNode = node:parent():parent()
	else
		u.notify("Not on a triple quoted string.", "warn")
		return
	end
	---@cast strNode TSNode

	local text = vim.treesitter.get_node_text(strNode, 0)
	local isMultiline = text:find("[\r\n]")

	local startRow, startCol, endRow, endCol = vim.treesitter.get_node_range(strNode)

	if scope == "inner" then
		local startNode = strNode:child(1) or strNode
		local endNode = strNode:child(strNode:child_count() - 2) or strNode
		startRow, startCol, _, _ = vim.treesitter.get_node_range(startNode)
		_, _, endRow, endCol = vim.treesitter.get_node_range(endNode)
	end

	-- fix various off-by-ones
	startRow = startRow + 1
	endRow = endRow + 1
	if scope == "inner" and isMultiline then
		endRow = endRow - 1
		endCol = #vim.api.nvim_buf_get_lines(0, endRow - 1, endRow, false)[1]
	else
		endCol = endCol - 1
	end

	charwise.setSelection({ startRow, startCol }, { endRow, endCol })
end

--------------------------------------------------------------------------------
return M

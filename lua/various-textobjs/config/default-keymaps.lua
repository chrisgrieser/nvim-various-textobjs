local M = {}
--------------------------------------------------------------------------------

local innerOuterMaps = {
	number = "n",
	value = "v",
	key = "k",
	subword = "S", -- lowercase taken for sentence textobj
	filepath = "F", -- `f` is usually used for outer/inner function textobjs
	notebookCell = "N",
	closedFold = "z", -- z is the common prefix for folds
	chainMember = "m",
	lineCharacterwise = "_",
	greedyOuterIndentation = "g",
	anyQuote = "q",
	anyBracket = "o",
	argument = ",",
	color = "#",
	doubleSquareBrackets = "D",
}
local oneMaps = {
	nearEoL = "n", -- does override the builtin "to next search match" textobj, but nobody really uses that
	visibleInWindow = "gw",
	toNextClosingBracket = "C", -- `%` has a race condition with vim's builtin matchit plugin
	toNextQuotationMark = "Q",
	restOfParagraph = "r",
	restOfIndentation = "R",
	restOfWindow = "gW",
	diagnostic = "!",
	column = "|",
	entireBuffer = "gG", -- `G` + `gg`
	url = "L", -- `gu`, `gU`, and `U` would conflict with `gugu`, `gUgU`, and `gUU`. `u` would conflict with `gcu` (undo comment)
	lastChange = "g;", -- consistent with `g;` movement
	emoji = ".", -- `:` would block the cmdline from visual mode, `e`/`E` conflicts with motions
}

--------------------------------------------------------------------------------

function M.setup(disabledKeymaps)
	local function keymap(...)
		local args = { ... }
		if vim.tbl_contains(disabledKeymaps, args[2]) then return end
		vim.keymap.set(...)
	end

	for objName, map in pairs(oneMaps) do
		keymap(
			{ "o", "x" },
			map,
			"<cmd>lua require('various-textobjs')." .. objName .. "()<CR>",
			{ desc = objName .. " textobj" }
		)
	end

	for objName, map in pairs(innerOuterMaps) do
		local name = " " .. objName .. " textobj"
		keymap(
			{ "o", "x" },
			"a" .. map,
			"<cmd>lua require('various-textobjs')." .. objName .. "('outer')<CR>",
			{ desc = "outer" .. name }
		)
		keymap(
			{ "o", "x" },
			"i" .. map,
			"<cmd>lua require('various-textobjs')." .. objName .. "('inner')<CR>",
			{ desc = "inner" .. name }
		)
	end
	-- stylua: ignore start
	keymap( { "o", "x" }, "ii" , "<cmd>lua require('various-textobjs').indentation('inner', 'inner')<CR>", { desc = "inner-inner indentation textobj" })
	keymap( { "o", "x" }, "ai" , "<cmd>lua require('various-textobjs').indentation('outer', 'inner')<CR>", { desc = "outer-inner indentation textobj" })
	keymap( { "o", "x" }, "iI" , "<cmd>lua require('various-textobjs').indentation('inner', 'inner')<CR>", { desc = "inner-inner indentation textobj" })
	keymap( { "o", "x" }, "aI" , "<cmd>lua require('various-textobjs').indentation('outer', 'outer')<CR>", { desc = "outer-outer indentation textobj" })
	-- stylua: ignore end
end

--------------------------------------------------------------------------------
return M

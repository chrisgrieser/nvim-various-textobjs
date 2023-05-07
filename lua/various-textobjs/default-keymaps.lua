local M = {}
--------------------------------------------------------------------------------

local innerOuterMaps = {
	number = "n",
	value = "v",
	key = "k",
	subword = "S", -- lowercase taken for sentence textobj
	closedFold = "z", -- z is the common prefix for folds
	chainMember = "m",
	lineCharacterwise = "_",
}
local oneMaps = {
	nearEoL = "n",
	visibleInWindow = "gw",
	toNextClosingBracket = "%", -- since this is basically a more intuitive version of the standard "%" motion-as-textobj
	restOfParagraph = "r",
	restOfIndentation = "R",
	restOfWindow = "gW",
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
	{
		map = { htmlAttribute = "x" },
		fts = { "html", "css", "scss", "xml" },
	},
}

function M.setup()
	local keymap = vim.keymap.set
	for objName, map in pairs(innerOuterMaps) do
		local name = " " .. objName .. " textobj"
		keymap(
			{ "o", "x" },
			"a" .. map,
			"<cmd>lua require('various-textobjs')." .. objName .. "(false)<CR>",
			{ desc = "outer" .. name }
		)
		keymap(
			{ "o", "x" },
			"i" .. map,
			"<cmd>lua require('various-textobjs')." .. objName .. "(true)<CR>",
			{ desc = "inner" .. name }
		)
	end
	for objName, map in pairs(oneMaps) do
		keymap(
			{ "o", "x" },
			map,
			"<cmd>lua require('various-textobjs')." .. objName .. "()<CR>",
			{ desc = objName .. " textobj" }
		)
	end
	-- stylua: ignore start
	keymap( { "o", "x" }, "ii" , "<cmd>lua require('various-textobjs').indentation(true, true)<CR>", { desc = "inner-inner indentation textobj" })
	keymap( { "o", "x" }, "ai" , "<cmd>lua require('various-textobjs').indentation(false, true)<CR>", { desc = "outer-inner indentation textobj" })
	keymap( { "o", "x" }, "iI" , "<cmd>lua require('various-textobjs').indentation(true, true)<CR>", { desc = "inner-inner indentation textobj" })
	keymap( { "o", "x" }, "aI" , "<cmd>lua require('various-textobjs').indentation(false, false)<CR>", { desc = "outer-outer indentation textobj" })

	vim.api.nvim_create_augroup("VariousTextobjs", {})
	for _, textobj in pairs(ftMaps) do
		vim.api.nvim_create_autocmd("FileType", {
			group = "VariousTextobjs",
			pattern = textobj.fts,
			callback = function()
				for objName, map in pairs(textobj.map) do
					local name = " " .. objName .. " textobj"
					keymap( { "o", "x" }, "a" .. map, ("<cmd>lua require('various-textobjs').%s(%s)<CR>"):format(objName, "false"), { desc = "outer" .. name, buffer = true })
					keymap( { "o", "x" }, "i" .. map, ("<cmd>lua require('various-textobjs').%s(%s)<CR>"):format(objName, "true"), { desc = "inner" .. name, buffer = true })
				end
			end,
		})
	end
	-- stylua: ignore end
end

--------------------------------------------------------------------------------
return M

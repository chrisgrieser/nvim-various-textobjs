local M = {}
--------------------------------------------------------------------------------

---@param userConfig? config
function M.setup(userConfig) require("various-textobjs.config").setup(userConfig) end

-- redirect calls to this module to the respective submodules
setmetatable(M, {
	__index = function(_, key)
		return function(...)
			local linewiseObjs = vim.tbl_keys(require("various-textobjs.linewise-textobjs"))

			local module = "charwise-textobjs"
			if vim.tbl_contains(linewiseObjs, key) then module = "linewise-textobjs" end
			if key == "column" then module = "blockwise-textobjs" end
			if key == "pyTripleQuotes" then module = "treesitter-textobjs" end
			require("various-textobjs." .. module)[key](...)
		end
	end,
})

--------------------------------------------------------------------------------
return M

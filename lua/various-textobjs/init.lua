local M = {}
--------------------------------------------------------------------------------

---@param userConfig? VariousTextobjs.Config
function M.setup(userConfig) require("various-textobjs.config").setup(userConfig) end

-- redirect calls to this module to the respective submodules
setmetatable(M, {
	__index = function(_, key)
		return function(...)
			local linewiseObjs = vim.tbl_keys(require("various-textobjs.textobjs.linewise"))

			local module = "charwise"
			if vim.tbl_contains(linewiseObjs, key) then module = "linewise" end
			if key == "column" then module = "blockwise" end
			if key == "pyTripleQuotes" then module = "treesitter" end
			require("various-textobjs.textobjs." .. module)[key](...)
		end
	end,
})

--------------------------------------------------------------------------------
return M

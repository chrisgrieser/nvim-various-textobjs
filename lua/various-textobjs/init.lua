local M = {}
--------------------------------------------------------------------------------

---@param userConfig? VariousTextobjs.Config
function M.setup(userConfig) require("various-textobjs.config.config").setup(userConfig) end

-- redirect calls to this module to the respective submodules
setmetatable(M, {
	__index = function(_, key)
		return function(...)
			local linewiseObjs = vim.tbl_keys(require("various-textobjs.textobjs.linewise"))

			local module = "charwise"
			if vim.tbl_contains(linewiseObjs, key) then module = "linewise" end
			if key == "column" then module = "blockwise" end
			if key == "diagnostic" then module = "diagnostic" end
			if key == "subword" then module = "subword" end
			if key == "emoji" then module = "emoji" end

			if key == "pyTripleQuotes" then
				local msg = "The `pyTripleQuotes` textobj is deprecated. "
					.. "Please use `nvim-treesitter-teextobjects`, create a file "
					.. "`./queries/python/textobjects.scm` in your config dir with "
					.. "the following content:\n\n"
					.. "```\n"
					.. "; extends\n"
					.. "(expression_statement (string (string_content) @docstring.inner) @docstring.outer)\n"
					.. "```\n"
					.. "Call the textobject via `:TSTextobjectSelect @docstring.outer`"
				require("various-textobjs.utils").warn(msg)
				return function() end -- empty function to prevent error
			end

			require("various-textobjs.textobjs." .. module)[key](...)
		end
	end,
})

--------------------------------------------------------------------------------
return M

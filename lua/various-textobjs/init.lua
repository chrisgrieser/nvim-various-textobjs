local M = {}
--------------------------------------------------------------------------------

---@param userConfig? VariousTextobjs.Config
function M.setup(userConfig) require("various-textobjs.config.config").setup(userConfig) end

-- redirect calls to this module to the respective submodules
setmetatable(M, {
	__index = function(_, key)
		return function(...)
			local warn = require("various-textobjs.utils").warn

			-- DEPRECATION (2025-04-24)
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
				warn(msg)
				return function() end -- empty function to prevent error
			end

			local linewiseObjs = vim.tbl_keys(require("various-textobjs.textobjs.linewise"))
			local charwiseObjs = vim.tbl_keys(require("various-textobjs.textobjs.charwise"))

			local module
			if vim.tbl_contains(linewiseObjs, key) then module = "linewise" end
			if vim.tbl_contains(charwiseObjs, key) then module = "charwise" end
			if key == "column" or key == "column_up" then module = "blockwise" end
			if key == "diagnostic" then module = "diagnostic" end
			if key == "subword" then module = "subword" end
			if key == "emoji" then module = "emoji" end

			if module then
				require("various-textobjs.textobjs." .. module)[key](...)
			else
				local msg = ("There is no text object called `%s`.\n\n"):format(key)
					.. "Make sure it exists in the list of text objects, and that you haven't misspelled it."
				warn(msg)
			end
		end
	end,
})

--------------------------------------------------------------------------------
return M

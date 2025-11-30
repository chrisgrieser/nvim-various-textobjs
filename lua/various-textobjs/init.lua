local M = {}
--------------------------------------------------------------------------------

---@param userConfig? VariousTextobjs.Config
function M.setup(userConfig) require("various-textobjs.config.config").setup(userConfig) end

-- redirect calls to this module to the respective submodules
setmetatable(M, {
	__index = function(_, key)
		return function(...)
			local warn = require("various-textobjs.utils").warn

			local linewiseObjs = vim.tbl_keys(require("various-textobjs.textobjs.linewise"))
			local charwiseObjs = vim.tbl_keys(require("various-textobjs.textobjs.charwise"))

			local module
			if vim.tbl_contains(linewiseObjs, key) then module = "linewise" end
			if vim.tbl_contains(charwiseObjs, key) then module = "charwise" end
			if key == "column" then module = "blockwise" end
			if key == "diagnostic" then module = "diagnostic" end
			if key == "subword" then module = "subword" end
			if key == "emoji" then module = "emoji" end

			-- DEPRECATION (2025-11-30)
			if key == "mdFencedCodeBlock" then
				local msg = "The `mdFencedCodeBlock` textobj is deprecated. "
					.. "Please use `nvim-treesitter-teextobjects`, create a file "
					.. "`./queries/markdown/textobjects.scm` in your config dir with "
					.. "the following content:\n\n"
					.. "```\n"
					.. "; extends\n"
					.. "(fenced_code_block) @codeblock.outer\n"
					.. "(code_fence_content) @codeblock.inner\n"
					.. "```\n"
					.. "Call the textobject via `:TSTextobjectSelect @codeblock.outer`"
				warn(msg)
				return function() end -- empty function to prevent error
			elseif key == "mdLink" then
				local msg = "The `mdLink` textobj is deprecated. "
					.. "Please use `nvim-treesitter-teextobjects`, create a file "
					.. "`./queries/markdown_inline/textobjects.scm` in your config dir with "
					.. "the following content:\n\n"
					.. "```\n"
					.. "; extends\n"
					.. "(inline_link) @mdlink.outer\n"
					.. "(link_text) @mdlink.inner\n"
					.. "```\n"
					.. "Call the textobject via `:TSTextobjectSelect @mdlink.outer`"
				warn(msg)
				return function() end -- empty function to prevent error
			elseif key == "mdEmphasis" then
				local msg = "The `mdEmphasis` textobj is deprecated. "
					.. "Please use `nvim-treesitter-teextobjects`, create a file "
					.. "`./queries/markdown_inline/textobjects.scm` in your config dir with "
					.. "the following content:\n\n"
					.. "```\n"
					.. "; extends\n"
					.. "(emphasis) @emphasis.outer\n"
					.. "(strong_emphasis) @emphasis.outer\n"
					.. "```\n"
					.. "Call the textobject via `:TSTextobjectSelect @emphasis.outer`"
				warn(msg)
				return function() end -- empty function to prevent error
			elseif key == "cssSelector" then
				local msg = "The `cssSelector` textobj is deprecated. "
					.. "Please use `nvim-treesitter-teextobjects`, create a file "
					.. "`./queries/css/textobjects.scm` in your config dir with "
					.. "the following content:\n\n"
					.. "```\n"
					.. "; extends\n"
					.. '(class_selector "." @selector.outer (class_name) @selector.inner @selector.outer)\n'
					.. "```\n"
					.. "Call the textobject via `:TSTextobjectSelect @selector.outer`"
				warn(msg)
				return function() end -- empty function to prevent error
			elseif key == "shellPipe" then
				local msg = "The `shellPipe` textobj is deprecated. "
					.. "Please use `nvim-treesitter-teextobjects`, create a file "
					.. "`./queries/{zsh,bash}/textobjects.scm` in your config dir with "
					.. "the following content:\n\n"
					.. "```\n"
					.. "; extends\n"
					.. '(pipeline (command) @pipeline.inner @pipeline.outer "|" @pipeline.outer)\n'
					.. "```\n"
					.. "Call the textobject via `:TSTextobjectSelect @pipeline.outer`"
				warn(msg)
				return function() end -- empty function to prevent error
			end

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

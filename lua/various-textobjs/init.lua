local M = {}

-- PERF do not import submodules here, since it results in them all being loaded
-- on initialization instead of lazy-loading them when needed.
--------------------------------------------------------------------------------

local notifiedOnce = false -- only notify once

---INFO this function ensures backwards compatibility with earlier versions,
---where the input arg for selecting the inner or outer textobj was a boolean.
---For verbosity reasons, this is now a string.
---@param arg any
---@return "outer"|"inner"
local function argConvert(arg)
	if arg == "outer" or arg == "inner" then return arg end

	local u = require("various-textobjs.utils")
	if not notifiedOnce and (arg == false or arg == true) then
		local msg = "`true` and `false` are deprecated as textobject arguments. "
			.. 'Use `"inner"` or `"outer"` instead.'
		u.notify(msg, "warn")
		notifiedOnce = true
	end
	if arg == true then return "inner" end
	return "outer"
end

---TODO This is the only function that takes more than one argument, thus
---prevent the simple use of `__index`. When `argConvert` is removed, `__index`
---can use `...` to pass all arguments, making this function unnecessary.
---@param startBorder "inner"|"outer" exclude the startline
---@param endBorder "inner"|"outer" exclude the endline
---@param blankLines? "withBlanks"|"noBlanks"
function M.indentation(startBorder, endBorder, blankLines)
	require("various-textobjs.linewise-textobjs").indentation(
		argConvert(startBorder),
		argConvert(endBorder),
		blankLines
	)
end

--------------------------------------------------------------------------------

---optional setup function
---@param userConfig? config
function M.setup(userConfig) require("various-textobjs.config").setup(userConfig) end

--------------------------------------------------------------------------------

-- redirect calls to this module to the charwise-textobjs submodule
setmetatable(M, {
	__index = function(_, key)
		return function(scope)
			local _scope = argConvert(scope)
			local linewiseObjs = vim.tbl_keys(require("various-textobjs.linewise-textobjs"))

			local module = "charwise-textobjs"
			if vim.tbl_contains(linewiseObjs, key) then module = "linewise-textobjs" end
			if key == "column" then module = "blockwise-textobjs" end
			if key == "pyTripleQuotes" then module = "treesitter-textobjs" end
			require("various-textobjs." .. module)[key](_scope)
		end
	end,
})

--------------------------------------------------------------------------------
return M

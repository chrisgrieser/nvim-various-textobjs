local M = {}
--------------------------------------------------------------------------------

-- DEPRECATION (2024-12-04)
setmetatable(M, {
	__index = function(_, key)
		if key == "urlPattern" then
			local msg =
				'`require("various-textobjs.charwise-textobjs").urlPattern` is deprecated. Just use this pattern instead: "%l%l%l-://[^%s)]+"'
			require("various-textobjs.utils").warn(msg)
		end
	end,
})

--------------------------------------------------------------------------------
return M

local M = {}
local core = require("various-textobjs.charwise-core")
local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

function M.diagnostic(oldWrapSetting)
	-- DEPRECATION (2024-12-03)
	if oldWrapSetting ~= nil then
		local msg =
			'`.diagnostic()` does not use a "wrap" argument anymore. Use the config `textobjs.diagnostic.wrap` instead.'
		u.warn(msg)
	end

	local wrap = require("various-textobjs.config.config").config.textobjs.diagnostic.wrap

	-- HACK if cursor is standing on a diagnostic, get_prev() will return that
	-- diagnostic *BUT* only if the cursor is not on the first character of the
	-- diagnostic, since the columns checked seem to be off-by-one as well m(
	-- Therefore counteracted by temporarily moving the cursor
	u.normal("l")
	local prevD = vim.diagnostic.get_prev { wrap = false }
	u.normal("h")

	local nextD = vim.diagnostic.get_next { wrap = wrap }
	local curStandingOnPrevD = false -- however, if prev diag is covered by or before the cursor has yet to be determined
	local curRow, curCol = unpack(vim.api.nvim_win_get_cursor(0))

	if prevD then
		local curAfterPrevDstart = (curRow == prevD.lnum + 1 and curCol >= prevD.col)
			or (curRow > prevD.lnum + 1)
		local curBeforePrevDend = (curRow == prevD.end_lnum + 1 and curCol <= prevD.end_col - 1)
			or (curRow < prevD.end_lnum)
		curStandingOnPrevD = curAfterPrevDstart and curBeforePrevDend
	end

	local target = curStandingOnPrevD and prevD or nextD
	if target then
		core.setSelection(
			{ target.lnum + 1, target.col },
			{ target.end_lnum + 1, target.end_col - 1 }
		)
	else
		u.notFoundMsg("No diagnostic found.")
	end
end

--------------------------------------------------------------------------------
return M

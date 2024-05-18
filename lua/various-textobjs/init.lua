local M = {}

-- PERF do not import submodules here, since it results in them all being loaded
-- on initialization instead of lazy-loading them when needed.
--------------------------------------------------------------------------------

---INFO this function ensures backwards compatibility with earlier versions,
---where the input arg for selecting the inner or outer textobj was a boolean.
---For verbosity reasons, this is now a string.
---@param arg any
---@return "outer"|"inner"
local function argConvert(arg)
	if arg == false then return "outer" end
	if arg == true then return "inner" end
	if arg == "outer" or arg == "inner" then return arg end
	require("various-textobjs.utils").notify(
		"Invalid argument for textobject, only 'outer' and 'inner' accepted. Falling back to outer textobject.",
		"warn"
	)
	return "outer"
end

--------------------------------------------------------------------------------

---optional setup function
---@param userConfig? config
function M.setup(userConfig)
	require("various-textobjs.config").setup(userConfig)
	local config = require("various-textobjs.config").config

	if config.useDefaultKeymaps then
		require("various-textobjs.default-keymaps").setup(config.disabledKeymaps)
	end
end

--------------------------------------------------------------------------------
-- LINEWISE

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

function M.restOfIndentation() require("various-textobjs.linewise-textobjs").restOfIndentation() end

---@param scope "inner"|"outer" outer adds a blank, like ip/ap textobjs
function M.greedyOuterIndentation(scope)
	require("various-textobjs.linewise-textobjs").greedyOuterIndentation(argConvert(scope))
end

---@param scope "inner"|"outer" outer adds one line after the fold
function M.closedFold(scope)
	require("various-textobjs.linewise-textobjs").closedFold(argConvert(scope))
end

---@param scope "inner"|"outer" inner excludes the backticks
function M.mdFencedCodeBlock(scope)
	require("various-textobjs.linewise-textobjs").mdFencedCodeBlock(argConvert(scope))
end

---@param scope "inner"|"outer" inner excludes the `"""`
function M.pyTripleQuotes(scope)
	require("various-textobjs.charwise-textobjs").pyTripleQuotes(argConvert(scope))
end

---@param scope "inner"|"outer" outer includes bottom cell border
function M.notebookCell(scope)
	require("various-textobjs.linewise-textobjs").notebookCell(argConvert(scope))
end

function M.restOfParagraph() require("various-textobjs.linewise-textobjs").restOfParagraph() end
function M.visibleInWindow() require("various-textobjs.linewise-textobjs").visibleInWindow() end
function M.restOfWindow() require("various-textobjs.linewise-textobjs").restOfWindow() end
function M.entireBuffer() require("various-textobjs.linewise-textobjs").entireBuffer() end

--------------------------------------------------------------------------------
-- BLOCKWISE

function M.column() require("various-textobjs.blockwise-textobjs").column() end

--------------------------------------------------------------------------------
-- CHARWISE

function M.nearEoL() require("various-textobjs.charwise-textobjs").nearEoL() end
function M.lineCharacterwise(scope)
	require("various-textobjs.charwise-textobjs").lineCharacterwise(argConvert(scope))
end
function M.toNextClosingBracket()
	require("various-textobjs.charwise-textobjs").toNextClosingBracket()
end
function M.toNextQuotationMark() require("various-textobjs.charwise-textobjs").toNextQuotationMark() end
function M.url() require("various-textobjs.charwise-textobjs").url() end

---@param wrap "wrap"|"nowrap"
function M.diagnostic(wrap) require("various-textobjs.charwise-textobjs").diagnostic(wrap) end
function M.lastChange() require("various-textobjs.charwise-textobjs").lastChange() end

---@param scope "inner"|"outer"
function M.anyQuote(scope) require("various-textobjs.charwise-textobjs").anyQuote(argConvert(scope)) end

---@param scope "inner"|"outer"
function M.anyBracket(scope)
	require("various-textobjs.charwise-textobjs").anyBracket(argConvert(scope))
end

---@param scope "inner"|"outer" inner value excludes trailing commas or semicolons, outer includes them. Both exclude trailing comments.
function M.value(scope) require("various-textobjs.charwise-textobjs").value(argConvert(scope)) end

---@param scope "inner"|"outer" outer key includes the `:` or `=` after the key
function M.key(scope) require("various-textobjs.charwise-textobjs").key(argConvert(scope)) end

---@param scope "inner"|"outer" inner number consists purely of digits, outer number factors in decimal points and includes minus sign
function M.number(scope) require("various-textobjs.charwise-textobjs").number(argConvert(scope)) end

---@param scope "inner"|"outer" outer includes trailing -_
function M.subword(scope) require("various-textobjs.charwise-textobjs").subword(argConvert(scope)) end

---see #26
---@param scope "inner"|"outer" inner excludes the leading dot
function M.chainMember(scope)
	require("various-textobjs.charwise-textobjs").chainMember(argConvert(scope))
end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---@param scope "inner"|"outer" inner link only includes the link title, outer link includes link, url, and the four brackets.
function M.mdlink(scope) require("various-textobjs.charwise-textobjs").mdlink(argConvert(scope)) end

---@param scope "inner"|"outer" inner selector only includes the content, outer selector includes the type.
function M.mdEmphasis(scope)
	require("various-textobjs.charwise-textobjs").mdEmphasis(argConvert(scope))
end

---@param scope "inner"|"outer" inner double square brackets exclude the brackets themselves
function M.doubleSquareBrackets(scope)
	require("various-textobjs.charwise-textobjs").doubleSquareBrackets(argConvert(scope))
end

---@param scope "inner"|"outer" outer selector includes trailing comma and whitespace
function M.cssSelector(scope)
	require("various-textobjs.charwise-textobjs").cssSelector(argConvert(scope))
end

---@param scope "inner"|"outer"
function M.cssColor(scope) require("various-textobjs.charwise-textobjs").cssColor(argConvert(scope)) end

---@param scope "inner"|"outer" inner selector is only the value of the attribute inside the quotation marks.
function M.htmlAttribute(scope)
	require("various-textobjs.charwise-textobjs").htmlAttribute(argConvert(scope))
end

---@param scope "inner"|"outer" outer selector includes the front pipe
function M.shellPipe(scope)
	require("various-textobjs.charwise-textobjs").shellPipe(argConvert(scope))
end

--------------------------------------------------------------------------------
return M

local M = {}

local blockwise = require("various-textobjs.blockwise-textobjs")
local charwise = require("various-textobjs.charwise-textobjs")
local linewise = require("various-textobjs.linewise-textobjs")
local u = require("various-textobjs.utils")
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

	u.notify(
		"Invalid argument for textobject, only 'outer' and 'inner' accepted. Falling back to outer textobject.",
		"warn"
	)
	return "outer"
end

--------------------------------------------------------------------------------
---@type config
local defaultConfig = {
	lookForwardSmall = 5,
	lookForwardBig = 15,
	useDefaultKeymaps = false,
	disabledKeymaps = {},
}
local config = defaultConfig

---@class config
---@field lookForwardSmall? number
---@field lookForwardBig? number
---@field useDefaultKeymaps? boolean
---@field disabledKeymaps? string[]

---optional setup function
---@param userConfig? config
function M.setup(userConfig)
	config = vim.tbl_deep_extend("force", defaultConfig, userConfig or {})

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
	linewise.indentation(argConvert(startBorder), argConvert(endBorder), blankLines)
end

function M.restOfIndentation() linewise.restOfIndentation() end

---@param scope "inner"|"outer" outer adds a blank, like ip/ap textobjs
function M.greedyOuterIndentation(scope) linewise.greedyOuterIndentation(argConvert(scope)) end

---@param scope "inner"|"outer" outer adds one line after the fold
function M.closedFold(scope) linewise.closedFold(argConvert(scope), config.lookForwardBig) end

---@param scope "inner"|"outer" inner excludes the backticks
function M.mdFencedCodeBlock(scope)
	linewise.mdFencedCodeBlock(argConvert(scope), config.lookForwardBig)
end

---@param scope "inner"|"outer" inner excludes the `"""`
function M.pyTripleQuotes(scope) charwise.pyTripleQuotes(argConvert(scope)) end

---@param scope "inner"|"outer" outer includes bottom cell border
function M.notebookCell(scope) linewise.notebookCell(argConvert(scope)) end

function M.restOfParagraph() linewise.restOfParagraph() end
function M.visibleInWindow() linewise.visibleInWindow() end
function M.restOfWindow() linewise.restOfWindow() end
function M.multiCommentedLines() linewise.multiCommentedLines(config.lookForwardBig) end
function M.entireBuffer() linewise.entireBuffer() end

--------------------------------------------------------------------------------
-- BLOCKWISE

function M.column() blockwise.column() end

--------------------------------------------------------------------------------
-- CHARWISE

function M.nearEoL() charwise.nearEoL() end
function M.lineCharacterwise(scope) charwise.lineCharacterwise(argConvert(scope)) end
function M.toNextClosingBracket() charwise.toNextClosingBracket(config.lookForwardSmall) end
function M.toNextQuotationMark() charwise.toNextQuotationMark(config.lookForwardSmall) end
function M.url() charwise.url(config.lookForwardBig) end
function M.diagnostic() charwise.diagnostic(config.lookForwardBig) end

---@param scope "inner"|"outer"
function M.anyQuote(scope) charwise.anyQuote(argConvert(scope), config.lookForwardSmall) end

---@param scope "inner"|"outer"
function M.anyBracket(scope) charwise.anyBracket(argConvert(scope), config.lookForwardSmall) end

---@param scope "inner"|"outer" inner value excludes trailing commas or semicolons, outer includes them. Both exclude trailing comments.
function M.value(scope) charwise.value(argConvert(scope), config.lookForwardSmall) end

---@param scope "inner"|"outer" outer key includes the `:` or `=` after the key
function M.key(scope) charwise.key(argConvert(scope), config.lookForwardSmall) end

---@param scope "inner"|"outer" inner number consists purely of digits, outer number factors in decimal points and includes minus sign
function M.number(scope) charwise.number(argConvert(scope), config.lookForwardSmall) end

---@param scope "inner"|"outer" outer includes trailing -_
function M.subword(scope) charwise.subword(argConvert(scope)) end

---see #26
---@param scope "inner"|"outer" inner excludes the leading dot
function M.chainMember(scope) charwise.chainMember(argConvert(scope), config.lookForwardSmall) end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---@param scope "inner"|"outer" inner link only includes the link title, outer link includes link, url, and the four brackets.
function M.mdlink(scope) charwise.mdlink(argConvert(scope), config.lookForwardSmall) end

---@param scope "inner"|"outer" inner double square brackets exclude the brackets themselves
function M.doubleSquareBrackets(scope)
	charwise.doubleSquareBrackets(argConvert(scope), config.lookForwardSmall)
end

---@param scope "inner"|"outer" outer selector includes trailing comma and whitespace
function M.cssSelector(scope) charwise.cssSelector(argConvert(scope), config.lookForwardSmall) end

---@param scope "inner"|"outer" inner selector is only the value of the attribute inside the quotation marks.
function M.htmlAttribute(scope) charwise.htmlAttribute(argConvert(scope), config.lookForwardSmall) end

---@param scope "inner"|"outer" outer selector includes the front pipe
function M.shellPipe(scope) charwise.shellPipe(argConvert(scope), config.lookForwardSmall) end

--------------------------------------------------------------------------------
return M

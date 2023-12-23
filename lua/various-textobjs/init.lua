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
	if arg ~= "outer" and arg ~= "inner" then
		u.notify(
			"Invalid argument for textobject, only 'outer' and 'inner' accepted. Falling back to outer textobject.",
			"warn"
		)
		return "outer"
	end
	return arg
end

--------------------------------------------------------------------------------
-- CONFIG
-- default values when not setup function is run
local lookForwardSmall = 5
local lookForwardBig = 15

---@class config
---@field lookForwardSmall? number
---@field lookForwardBig? number
---@field useDefaultKeymaps? boolean
---@field disabledKeymaps? string[]

---optional setup function
---@param userConfig config
function M.setup(userConfig)
	---@type config
	local defaultConfig = {
		lookForwardSmall = 5,
		lookForwardBig = 15,
		useDefaultKeymaps = false,
		disabledKeymaps = {},
	}
	local config = vim.tbl_deep_extend("keep", userConfig, defaultConfig)

	lookForwardSmall = config.lookForwardSmall
	lookForwardBig = config.lookForwardBig
	if config.useDefaultKeymaps then
		require("various-textobjs.default-keymaps").setup(config.disabledKeymaps)
	end
end

--------------------------------------------------------------------------------
-- LINEWISE

---rest of paragraph (linewise)
function M.restOfParagraph() linewise.restOfParagraph() end

---Textobject for the entire buffer content
function M.entireBuffer() linewise.entireBuffer() end

---indentation textobj
---@param startBorder "inner"|"outer" exclude the startline
---@param endBorder "inner"|"outer" exclude the endline
---@param blankLines? "withBlanks"|"noBlanks"
function M.indentation(startBorder, endBorder, blankLines)
	linewise.indentation(argConvert(startBorder), argConvert(endBorder), blankLines)
end

---from cursor position down all lines with same or higher indentation;
---essentially `ii` downwards
function M.restOfIndentation() linewise.restOfIndentation() end

---outer indentation, expanded until the next blank lines in both directions
---@param scope "inner"|"outer" outer adds a blank, like ip/ap textobjs
function M.greedyOuterIndentation(scope) linewise.greedyOuterIndentation(argConvert(scope)) end

---@param scope "inner"|"outer" outer adds one line after the fold
function M.closedFold(scope) linewise.closedFold(argConvert(scope), lookForwardBig) end

---@param scope "inner"|"outer" inner excludes the backticks
function M.mdFencedCodeBlock(scope) linewise.mdFencedCodeBlock(argConvert(scope), lookForwardBig) end

---@param scope "inner"|"outer" inner excludes the `"""`
function M.pyTripleQuotes(scope) charwise.pyTripleQuotes(argConvert(scope)) end

---lines visible in window textobj
function M.visibleInWindow() linewise.visibleInWindow() end

-- from cursor line to last visible line in window
function M.restOfWindow() linewise.restOfWindow() end

function M.multiCommentedLines() linewise.multiCommentedLines(lookForwardBig) end

---for plugins like NotebookNavigator.nvim
---@param scope "inner"|"outer" outer includes bottom cell border
function M.notebookCell(scope) linewise.notebookCell(argConvert(scope)) end
--------------------------------------------------------------------------------
-- BLOCKWISE

---Column Textobj (blockwise down until indent or shorter line)
function M.column() blockwise.column() end

--------------------------------------------------------------------------------
-- CHARWISE

---field which includes a call
---see also https://github.com/chrisgrieser/nvim-various-textobjs/issues/26
---@param scope "inner"|"outer" inner excludes the leading dot
function M.chainMember(scope) charwise.chainMember(argConvert(scope), lookForwardSmall) end

---Subword
---@param scope "inner"|"outer" outer includes trailing -_
function M.subword(scope) charwise.subword(argConvert(scope)) end

---near end of the line, ignoring trailing whitespace (relevant for markdown)
function M.nearEoL() charwise.nearEoL() end

---till next closing bracket
function M.toNextClosingBracket() charwise.toNextClosingBracket(lookForwardSmall) end

---till next quotation mark (backtick counts as one)
function M.toNextQuotationMark() charwise.toNextQuotationMark(lookForwardSmall) end

function M.anyQuote(scope) charwise.anyQuote(argConvert(scope), lookForwardSmall) end

function M.anyBracket(scope) charwise.anyBracket(argConvert(scope), lookForwardSmall) end

---current line (but characterwise)
function M.lineCharacterwise(scope) charwise.lineCharacterwise(argConvert(scope)) end

---diagnostic text object
---similar to https://github.com/andrewferrier/textobj-diagnostic.nvim
---requires builtin lsp
function M.diagnostic() charwise.diagnostic(lookForwardBig) end

---@param scope "inner"|"outer" inner value excludes trailing commas or semicolons, outer includes them. Both exclude trailing comments.
function M.value(scope) charwise.value(argConvert(scope), lookForwardSmall) end

---@param scope "inner"|"outer" outer key includes the `:` or `=` after the key
function M.key(scope) charwise.key(argConvert(scope), lookForwardSmall) end

---number textobj
---@deprecated use corresponding treesitter-textobject instead
---@param scope "inner"|"outer" inner number consists purely of digits, outer number factors in decimal points and includes minus sign
function M.number(scope) charwise.number(argConvert(scope), lookForwardSmall) end

---URL textobj
function M.url() charwise.url(lookForwardBig) end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---md links textobj
---@param scope "inner"|"outer" inner link only includes the link title, outer link includes link, url, and the four brackets.
function M.mdlink(scope) charwise.mdlink(argConvert(scope), lookForwardSmall) end

---double square brackets
---@param scope "inner"|"outer" inner double square brackets exclude the brackets themselves
function M.doubleSquareBrackets(scope) charwise.doubleSquareBrackets(argConvert(scope), lookForwardSmall) end

---CSS Selector Textobj
---@param scope "inner"|"outer" outer selector includes trailing comma and whitespace
function M.cssSelector(scope) charwise.cssSelector(argConvert(scope), lookForwardSmall) end

---HTML/XML Attribute Textobj
---@param scope "inner"|"outer" inner selector is only the value of the attribute inside the quotation marks.
function M.htmlAttribute(scope) charwise.htmlAttribute(argConvert(scope), lookForwardSmall) end

---Shell Pipe Textobj
---@param scope "inner"|"outer" outer selector includes the front pipe
function M.shellPipe(scope) charwise.shellPipe(argConvert(scope), lookForwardSmall) end

--------------------------------------------------------------------------------
return M

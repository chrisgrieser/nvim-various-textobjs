local M = {}

local blockwise = require("various-textobjs.blockwise-textobjs")
local charwise = require("various-textobjs.charwise-textobjs")
local linewise = require("various-textobjs.linewise-textobjs")
local setupDefaultKeymaps = require("various-textobjs.default-keymaps").setup

--------------------------------------------------------------------------------
-- CONFIG
-- default value
local lookForwL = 5

---optional setup function
---@param opts table
function M.setup(opts)
	if not opts then opts = {} end
	if opts.lookForwardLines then lookForwL = opts.lookForwardLines end
	if opts.useDefaultKeymaps then setupDefaultKeymaps() end
end

--------------------------------------------------------------------------------
-- LINEWISE

---rest of paragraph (linewise)
function M.restOfParagraph() linewise.restOfParagraph() end

---Textobject for the entire buffer content
function M.entireBuffer() linewise.entireBuffer() end

---indentation textobj
---@param noStartBorder boolean exclude the startline
---@param noEndBorder boolean exclude the endline
function M.indentation(noStartBorder, noEndBorder) linewise.indentation(noStartBorder, noEndBorder) end

---from cursor position down all lines with same or higher indentation;
---essentially `ii` downwards
function M.restOfIndentation() linewise.restOfIndentation() end

-- next *closed* fold
---@param inner boolean outer adds one line after the fold
function M.closedFold(inner) linewise.closedFold(inner, lookForwL) end

---Md Fenced Code Block Textobj
---@param inner boolean inner excludes the backticks
function M.mdFencedCodeBlock(inner) linewise.mdFencedCodeBlock(inner, lookForwL) end

--------------------------------------------------------------------------------
-- CHARWISE

---field which includes a call
---see also https://github.com/chrisgrieser/nvim-various-textobjs/issues/26
---@param inner boolean inner excludes the leading dot
function M.chainMember(inner) charwise.chainMember(inner, lookForwL) end

---Subword
---@param inner boolean outer includes trailing -_
function M.subword(inner) charwise.subword(inner, lookForwL) end

---near end of the line, ignoring trailing whitespace (relevant for markdown)
function M.nearEoL() charwise.nearEoL() end

---till next closing bracket
function M.toNextClosingBracket() charwise.toNextClosingBracket(lookForwL) end

---current line (but characterwise)
function M.lineCharacterwise() charwise.lineCharacterwise() end

---DIAGNOSTIC TEXT OBJECT
---similar to https://github.com/andrewferrier/textobj-diagnostic.nvim
---requires builtin LSP
function M.diagnostic() charwise.diagnostic(lookForwL) end

---Column Textobj (blockwise down until indent or shorter line)
function M.column() blockwise.column() end

---@param inner boolean inner value excludes trailing commas or semicolons, outer includes them. Both exclude trailing comments.
function M.value(inner) charwise.value(inner, lookForwL) end

---@param inner boolean outer key includes the `:` or `=` after the key
function M.key(inner) charwise.key(inner, lookForwL) end

---number textobj
---@deprecated use corresponding treesitter-textobject instead
---@param inner boolean inner number consists purely of digits, outer number factors in decimal points and includes minus sign
function M.number(inner) charwise.number(inner, lookForwL) end

---URL textobj
function M.url() charwise.url(lookForwL) end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---md links textobj
---@param inner boolean inner link only includes the link title, outer link includes link, url, and the four brackets.
function M.mdlink(inner) charwise.mdlink(inner, lookForwL) end

---double square brackets
---@param inner boolean inner double square brackets exclude the brackets themselves
function M.doubleSquareBrackets(inner) charwise.doubleSquareBrackets(inner, lookForwL) end

---JS Regex
---@deprecated use corresponding treesitter-textobject instead
---@param inner boolean inner regex excludes the slashes (and flags)
function M.jsRegex(inner) charwise.jsRegex(inner, lookForwL) end

---CSS Selector Textobj
---@param inner boolean outer selector includes trailing comma and whitespace
function M.cssSelector(inner) charwise.cssSelector(inner, lookForwL) end

---HTML/XML Attribute Textobj
---@param inner boolean inner selector is only the value of the attribute inside the quotation marks.
function M.htmlAttribute(inner) charwise.htmlAttribute(inner, lookForwL) end

---Shell Pipe Textobj
---@param inner boolean outer selector includes the front pipe
function M.shellPipe(inner) charwise.shellPipe(inner, lookForwL) end

--------------------------------------------------------------------------------
return M

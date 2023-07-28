local M = {}

local blockwise = require("various-textobjs.blockwise-textobjs")
local charwise = require("various-textobjs.charwise-textobjs")
local linewise = require("various-textobjs.linewise-textobjs")
local defaultKeymaps = require("various-textobjs.default-keymaps")

--------------------------------------------------------------------------------
-- CONFIG
-- default values
local lookForwardSmall = 5
local lookForwardBig = 15

---@class config
---@field lookForwardSmall number -- characterwise textobjs
---@field lookForwardBig number -- linewise textobjs & URL textobj
---@field useDefaultKeymaps boolean
---@field disabledKeymaps string[]

---optional setup function
---@param opts config
function M.setup(opts)
	if not opts then opts = {} end
	if opts.lookForwardSmall then lookForwardSmall = opts.lookForwardSmall end
	if opts.lookForwardBig then lookForwardBig = opts.lookForwardBig end
	if opts.useDefaultKeymaps then defaultKeymaps.setup(opts.disabledKeymaps or {}) end
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
function M.closedFold(inner) linewise.closedFold(inner, lookForwardBig) end

---Md Fenced Code Block Textobj
---@param inner boolean inner excludes the backticks
function M.mdFencedCodeBlock(inner) linewise.mdFencedCodeBlock(inner, lookForwardBig) end

---lines visible in window textobj
function M.visibleInWindow() linewise.visibleInWindow() end

-- from cursor line to last visible line in window
function M.restOfWindow() linewise.restOfWindow() end

--------------------------------------------------------------------------------
-- BLOCKWISE

---Column Textobj (blockwise down until indent or shorter line)
function M.column() blockwise.column() end

--------------------------------------------------------------------------------
-- CHARWISE

---field which includes a call
---see also https://github.com/chrisgrieser/nvim-various-textobjs/issues/26
---@param inner boolean inner excludes the leading dot
function M.chainMember(inner) charwise.chainMember(inner, lookForwardSmall) end

---Subword
---@param inner boolean outer includes trailing -_
function M.subword(inner) charwise.subword(inner) end

---near end of the line, ignoring trailing whitespace (relevant for markdown)
function M.nearEoL() charwise.nearEoL() end

---till next closing bracket
function M.toNextClosingBracket() charwise.toNextClosingBracket(lookForwardSmall) end

---current line (but characterwise)
function M.lineCharacterwise(inner) charwise.lineCharacterwise(inner) end

---diagnostic text object
---similar to https://github.com/andrewferrier/textobj-diagnostic.nvim
---requires builtin lsp
function M.diagnostic() charwise.diagnostic(lookForwardBig) end

---@param inner boolean inner value excludes trailing commas or semicolons, outer includes them. Both exclude trailing comments.
function M.value(inner) charwise.value(inner, lookForwardSmall) end

---@param inner boolean outer key includes the `:` or `=` after the key
function M.key(inner) charwise.key(inner, lookForwardSmall) end

---number textobj
---@deprecated use corresponding treesitter-textobject instead
---@param inner boolean inner number consists purely of digits, outer number factors in decimal points and includes minus sign
function M.number(inner) charwise.number(inner, lookForwardSmall) end

---URL textobj
function M.url() charwise.url(lookForwardBig) end

--------------------------------------------------------------------------------
-- FILETYPE SPECIFIC TEXTOBJS

---md links textobj
---@param inner boolean inner link only includes the link title, outer link includes link, url, and the four brackets.
function M.mdlink(inner) charwise.mdlink(inner, lookForwardSmall) end

---double square brackets
---@param inner boolean inner double square brackets exclude the brackets themselves
function M.doubleSquareBrackets(inner) charwise.doubleSquareBrackets(inner, lookForwardSmall) end

---CSS Selector Textobj
---@param inner boolean outer selector includes trailing comma and whitespace
function M.cssSelector(inner) charwise.cssSelector(inner, lookForwardSmall) end

---HTML/XML Attribute Textobj
---@param inner boolean inner selector is only the value of the attribute inside the quotation marks.
function M.htmlAttribute(inner) charwise.htmlAttribute(inner, lookForwardSmall) end

---Shell Pipe Textobj
---@param inner boolean outer selector includes the front pipe
function M.shellPipe(inner) charwise.shellPipe(inner, lookForwardSmall) end

--------------------------------------------------------------------------------
return M

<!-- LTeX: enabled=false -->
# nvim-various-textobjs 🟪🔷🟡
<!-- LTeX: enabled=true -->
<a href="https://dotfyle.com/plugins/chrisgrieser/nvim-various-textobjs">
<img alt="badge" src="https://dotfyle.com/plugins/chrisgrieser/nvim-various-textobjs/shield"/></a>

Bundle of more than 30 new textobjects for Neovim.

<!-- toc -->

- [List of Text Objects](#list-of-text-objects)
- [Non-Goals](#non-goals)
- [Installation](#installation)
- [Configuration](#configuration)
- [Advanced Usage / API](#advanced-usage--api)
	* [`ii` on unindented line should select entire buffer](#ii-on-unindented-line-should-select-entire-buffer)
	* [Smarter `gx`](#smarter-gx)
	* [Delete Surrounding Indentation](#delete-surrounding-indentation)
	* [Yank Surrounding Indentation](#yank-surrounding-indentation)
	* [Other Ideas?](#other-ideas)
- [Limitations](#limitations)
- [Other Text Object Plugins](#other-text-object-plugins)
- [Credits](#credits)

<!-- tocstop -->

## List of Text Objects
<!-- vale off -->
<!-- LTeX: enabled=false -->

| textobject             | description                                                                               | inner / outer                                                                             | forward-seeking |     default keymaps      | filetypes (for default keymaps) |
|:-----------------------|:------------------------------------------------------------------------------------------|:------------------------------------------------------------------------------------------|:----------------|:------------------------:|:--------------------------------|
| indentation            | surrounding lines with same or higher indentation                                         | [see overview from vim-indent-object](https://github.com/michaeljsmith/vim-indent-object) | \-              | `ii`, `ai`, `aI`, (`iI`) | all                             |
| restOfIndentation      | lines down with same or higher indentation                                                | \-                                                                                        | \-              |           `R`            | all                             |
| greedyOuterIndentation | outer indentation, expanded to blank lines; useful to get functions with annotations      | outer includes a blank, like `ap`/`ip`                                                    | \-              |        `ag`/`ig`         | all                             |
| subword                | like `iw`, but treating `-`, `_`, and `.` as word delimiters *and* only part of camelCase | outer includes trailing `_`,`-`, or space                                                 | \-              |        `iS`, `aS`        | all                             |
| toNextClosingBracket   | from cursor to next closing `]`, `)`, or `}`                                              | \-                                                                                        | small           |           `C`            | all                             |
| toNextQuotationMark    | from cursor to next unescaped[^1] `"`, `'`, or `` ` ``                                    | \-                                                                                        | small           |           `Q`            | all                             |
| anyQuote               | between any unescaped[^1] `"`, `'`, or `` ` `` *in a line*                                | outer includes the quotation marks                                                        | small           |           `iq`/`aq`      | all                             |
| anyBracket             | between any `()`, `[]`, or `{}` *in a line*                                               | outer includes the brackets                                                               | small           |           `io`/`ao`      | all                             |
| restOfParagraph        | like `}`, but linewise                                                                    | \-                                                                                        | \-              |           `r`            | all                             |
| multiCommentedLines    | consecutive, fully commented lines                                                        | \-                                                                                        | big             |           `gc`           | all                             |
| entireBuffer           | entire buffer as one text object                                                          | \-                                                                                        | \-              |           `gG`           | all                             |
| nearEoL                | from cursor position to end of line, minus one character                                  | \-                                                                                        | \-              |           `n`            | all                             |
| lineCharacterwise      | current line, but characterwise                                                           | outer includes indentation and trailing spaces                                            | \-              |        `i_`, `a_`        | all                             |
| column                 | column down until indent or shorter line. Accepts `{count}` for multiple columns.         | \-                                                                                        | \-              |           `\|`           | all                             |
| value                  | value of key-value pair, or right side of a assignment, excl. trailing comment (in a line)| outer includes trailing commas or semicolons                                              | small           |        `iv`, `av`        | all                             |
| key                    | key of key-value pair, or left side of a assignment                                       | outer includes the `=` or `:`                                                             | small           |        `ik`, `ak`        | all                             |
| url                    | works with `http[s]` or any other protocol                                                | \-                                                                                        | big             |           `L`            | all                             |
| number                 | numbers, similar to `<C-a>`                                                               | inner: only pure digits, outer: number including minus sign and decimal point             | small           |        `in`, `an`        | all                             |
| diagnostic             | LSP diagnostic (requires built-in LSP)                                                    | \-                                                                                        | big             |           `!`            | all                             |
| closedFold             | closed fold                                                                               | outer includes one line after the last folded line                                        | big             |        `iz`, `az`        | all                             |
| chainMember            | field with the full call, like `.encode(param)`                                           | outer includes the leading `.` (or `:`)                                                   | small           |        `im`, `am`        | all                             |
| visibleInWindow        | all lines visible in the current window                                                   | \-                                                                                        | \-              |           `gw`           | all                             |
| restOfWindow           | from the cursorline to the last line in the window                                        | \-                                                                                        | \-              |           `gW`           | all                             |
| lastChange             | Last non-deletion-change, yank, or paste.[^2]                                             | \-                                                                                        | \-              |           `g;`           | all                             |
| mdlink                 | markdown link like `[title](url)`                                                         | inner is only the link title (between the `[]`)                                           | small           |        `il`, `al`        | markdown, toml                  |
| mdFencedCodeBlock      | markdown fenced code (enclosed by three backticks)                                        | outer includes the enclosing backticks                                                    | big             |        `iC`, `aC`        | markdown                        |
| cssSelector            | class in CSS like `.my-class`                                                             | outer includes trailing comma and space                                                   | small           |        `ic`, `ac`        | css, scss                       |
| htmlAttribute          | attribute in html/xml like `href="foobar.com"`                                            | inner is only the value inside the quotes trailing comma and space                        | small           |        `ix`, `ax`        | html, xml, css, scss, vue       |
| doubleSquareBrackets   | text enclosed by `[[]]`                                                                   | outer includes the four square brackets                                                   | small           |        `iD`, `aD`        | lua, shell, neorg, markdown     |
| shellPipe              | segment until a pipe character (`\|`)                                                     | outer includes the pipe to the right                                                      | small           |        `iP`,`aP`         | bash, zsh, fish, sh             |
| pyTripleQuotes         | python strings surrounded by three quotes (regular or f-string)                           | inner excludes the `"""` or `'''`                                                         | \-              |        `iy`,`ay`         | python                          |
| notebookCell           | cell delimited by [double percent comment][jupytext], such as `# %%`                      | outer includes the bottom cell border                                                     | \-              |        `iN`,`aN`         | all                             |

[jupytext]: https://jupytext.readthedocs.io/en/latest/formats-scripts.html#the-percent-format
<!-- vale on -->
<!-- LTeX: enabled=true -->

## Non-Goals
[nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
already does an excellent job when it comes to using Treesitter for text
objects, such as function arguments or loops. This plugin's goal is therefore
not to provide textobjects already offered by `nvim-treesitter-textobjects`.

## Installation
Have `nvim-various-textobjs` set up text objects for you:

```lua
-- lazy.nvim
{
	"chrisgrieser/nvim-various-textobjs",
	lazy = false,
	opts = { useDefaultKeymaps = true },
},

-- packer
use {
	"chrisgrieser/nvim-various-textobjs",
	config = function () 
		require("various-textobjs").setup({ useDefaultKeymaps = true })
	end,
}
```

If you prefer to set up your own keybindings, use this code and then see the
[Configuration](#configuration) section for information on setting your own
keymaps.

```lua
-- lazy.nvim
{
	"chrisgrieser/nvim-various-textobjs",
	lazy = true,
},

-- packer
use { "chrisgrieser/nvim-various-textobjs" }
```

> [!TIP]  
> You can also use the `disabledKeymaps` config option to disable only *some*
> default keymaps.

## Configuration
The `.setup()` call is optional if you are fine with the defaults below.

```lua
-- default config
require("various-textobjs").setup {
	-- lines to seek forwards for "small" textobjs (mostly characterwise textobjs)
	-- set to 0 to only look in the current line
	lookForwardSmall = 5,

	-- lines to seek forwards for "big" textobjs (mostly linewise textobjs)
	lookForwardBig = 15,

	-- use suggested keymaps (see overview table in README)
	useDefaultKeymaps = false,

	-- disable only some default keymaps, e.g. { "ai", "ii" }
	disabledKeymaps = {},
}
```

---

If you want to set your own keybindings, you can do so by calling the respective
functions:
- The function names correspond to the textobject names from the [overview table](#list-of-text-objects).

<!-- vale Google.Will = NO -->
> [!NOTE]
> For dot-repeat to work, you have to call the motions as Ex-commands. When
> using `function() require("various-textobjs").diagnostic() end` as third
> argument of the keymap, dot-repeatability will not work.
<!-- vale Google.Will = YES -->

```lua
-- example: `?` for diagnostic textobj
vim.keymap.set({ "o", "x" }, "?", '<cmd>lua require("various-textobjs").diagnostic()<CR>')

-- example: `as` for outer subword, `is` for inner subword
vim.keymap.set({ "o", "x" }, "as", '<cmd>lua require("various-textobjs").subword("outer")<CR>')
vim.keymap.set({ "o", "x" }, "is", '<cmd>lua require("various-textobjs").subword("inner")<CR>')

-- exception: the indentation textobj requires two parameters, the first for
-- exclusion of the starting border, the second for the exclusion of ending
-- border
vim.keymap.set(
	{ "o", "x" },
	"ii",
	'<cmd>lua require("various-textobjs").indentation("inner", "inner")<CR>'
)
vim.keymap.set(
	{ "o", "x" },
	"ai",
	'<cmd>lua require("various-textobjs").indentation("outer", "inner")<CR>'
)

-- an additional parameter can be passed to control whether blank lines are included
vim.keymap.set(
	{ "o", "x" },
	"ai",
	'<cmd>lua require("various-textobjs").indentation("outer", "inner", "noBlanks")<CR>'
)
```

For your convenience, here the code to create mappings for all text objects. You
can copypaste this list and enter your own bindings.
<details>
<summary>➡️ Mappings for all text objects</summary>

```lua
local keymap = vim.keymap.set

keymap({ "o", "x" }, "ii", "<cmd>lua require('various-textobjs').indentation('inner', 'inner')<CR>")
keymap({ "o", "x" }, "ai", "<cmd>lua require('various-textobjs').indentation('outer', 'inner')<CR>")
keymap({ "o", "x" }, "iI", "<cmd>lua require('various-textobjs').indentation('inner', 'inner')<CR>")
keymap({ "o", "x" }, "aI", "<cmd>lua require('various-textobjs').indentation('outer', 'outer')<CR>")

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').restOfIndentation()<CR>")

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').greedyOuterIndentation('inner')<CR>"
)
keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').greedyOuterIndentation('outer')<CR>"
)

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').subword('inner')<CR>")
keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').subword('outer')<CR>")

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').toNextClosingBracket()<CR>"
)

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').toNextQuotationMark()<CR>"
)

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').anyQuote('inner')<CR>")
keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').anyQuote('outer')<CR>")

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').anyBracket('inner')<CR>")
keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').anyBracket('outer')<CR>")

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').restOfParagraph()<CR>")

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').entireBuffer()<CR>")

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').nearEoL()<CR>")

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').lastChange()<CR>")

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').lineCharacterwise('inner')<CR>"
)
keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').lineCharacterwise('outer')<CR>"
)

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').column()<CR>")

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').multiCommentedLines()<CR>"
)

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').notebookCell('inner')<CR>"
)
keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').notebookCell('outer')<CR>"
)

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').value('inner')<CR>")
keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').value('outer')<CR>")

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').key('inner')<CR>")
keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').key('outer')<CR>")

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').url()<CR>")

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').number('inner')<CR>")
keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').number('outer')<CR>")

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').diagnostic()<CR>")

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').closedFold('inner')<CR>")
keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').closedFold('outer')<CR>")

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').chainMember('inner')<CR>"
)
keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').chainMember('outer')<CR>"
)

keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').visibleInWindow()<CR>")
keymap({ "o", "x" }, "YOUR_MAPPING", "<cmd>lua require('various-textobjs').restOfWindow()<CR>")

--------------------------------------------------------------------------------------
-- put these into the ftplugins or autocmds for the filetypes you want to use them with

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').mdlink('inner')<CR>",
	{ buffer = true }
)
keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').mdlink('outer')<CR>",
	{ buffer = true }
)

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').mdFencedCodeBlock('inner')<CR>",
	{ buffer = true }
)
keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').mdFencedCodeBlock('outer')<CR>",
	{ buffer = true }
)

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').pyTripleQuotes('inner')<CR>",
	{ buffer = true }
)
keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').pyTripleQuotes('outer')<CR>",
	{ buffer = true }
)

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').cssSelector('inner')<CR>",
	{ buffer = true }
)
keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').cssSelector('outer')<CR>",
	{ buffer = true }
)

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').htmlAttribute('inner')<CR>",
	{ buffer = true }
)
keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').htmlAttribute('outer')<CR>",
	{ buffer = true }
)

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').doubleSquareBrackets('inner')<CR>",
	{ buffer = true }
)
keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').doubleSquareBrackets('outer')<CR>",
	{ buffer = true }
)

keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').shellPipe('inner')<CR>",
	{ buffer = true }
)
keymap(
	{ "o", "x" },
	"YOUR_MAPPING",
	"<cmd>lua require('various-textobjs').shellPipe('outer')<CR>",
	{ buffer = true }
)
```

</details>

## Advanced Usage / API
All textobjects can also be used as an API to modify their behavior or create
custom commands. Here are some examples:

### `ii` on unindented line should select entire buffer
Using a simple if-else-block, you can create a hybrid of the inner indentation
text object and the entire-buffer text object, you prefer that kind of behavior:

```lua
-- when on unindented line, `ii` should select entire buffer
vim.keymap.set("o", "ii", function()
	if vim.fn.indent(".") == 0 then
		require("various-textobjs").entireBuffer()
	else
		require("various-textobjs").indentation("inner", "inner")
	end
end)
```

### Smarter `gx`
The code below retrieves the next URL (within the amount of lines configured in
the `setup` call), and opens it in your browser. As opposed to vim's built-in
`gx`, this is **forward-seeking**, meaning your cursor does not have to stand on
the URL.

```lua
local function openURL()
	local opener
	if vim.fn.has("macunix") == 1 then
		opener = "open"
	elseif vim.fn.has("linux") == 1 then
		opener = "xdg-open"
	elseif vim.fn.has("win64") == 1 or vim.fn.has("win32") == 1 then
		opener = "start"
	end
	local openCommand = string.format("%s '%s' >/dev/null 2>&1", opener, url)
	vim.fn.system(openCommand)
end

vim.keymap.set("n", "gx", function()
	-- select URL
	require("various-textobjs").url()

	-- plugin only switches to visual mode when textobj found
	local foundURL = vim.fn.mode():find("v")
	if not foundURL then return end

	-- retrieve URL with the z-register as intermediary
	vim.cmd.normal { '"zy', bang = true }
	local url = vim.fn.getreg("z")
	openURL(url)
end, { desc = "URL Opener" })
```

You could go even further: When no URL can be found by `various-textobjs`, you
could retrieve all URLs in the buffer and select one to open. (The URL-pattern
used by this plugin is exposed for this purpose.)

```lua
vim.keymap.set("n", "gx", function()
	require("various-textobjs").url()
	local foundURL = vim.fn.mode():find("v") 
	if foundURL then
		u.normal('"zy')
		local url = vim.fn.getreg("z")
		openURL(url)
	else 
		-- find all URLs in buffer
		local urlPattern = require("various-textobjs.charwise-textobjs").urlPattern
		local bufText = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
		local urls = {}
		for url in bufText:gmatch(urlPattern) do
			table.insert(urls, url)
		end
		if #urls == 0 then return end

		-- select one, use a plugin like dressing.nvim for nicer UI for
		-- `vim.ui.select`
		vim.ui.select(urls, { prompt = "Select URL:" }, function(choice)
			if choice then openURL(url) end
		end)
	end
end, { desc = "URL Opener" })
```

### Delete Surrounding Indentation
Using the indentation textobject, you can also create custom indentation-related
utilities. A common operation is to remove the line before and after an
indentation. Take for example this case where you are removing the `foo`
condition:

```lua
-- before (cursor on `print("bar")`)
if foo then
	print("bar")
	print("baz")
end

-- after
print("bar")
print("baz")
```

The code below achieves this by dedenting the inner indentation textobject
(essentially running `<ii`), and deleting the two lines surrounding it. As for
the mapping, `dsi` should make sense since this command is somewhat similar to
the `ds` operator from [vim-surround](https://github.com/tpope/vim-surround) but
performed on an indentation textobject. (It is also an intuitive mnemonic:
`d`elete `s`urrounding `i`ndentation.)

```lua
vim.keymap.set("n", "dsi", function()
	-- select outer indentation
	require("various-textobjs").indentation("outer", "outer")

	-- plugin only switches to visual mode when a textobj has been found
	local indentationFound = vim.fn.mode():find("V")
	if not indentationFound then return end

	-- dedent indentation
	vim.cmd.normal { "<", bang = true }

	-- delete surrounding lines
	local endBorderLn = vim.api.nvim_buf_get_mark(0, ">")[1]
	local startBorderLn = vim.api.nvim_buf_get_mark(0, "<")[1]
	vim.cmd(tostring(endBorderLn) .. " delete") -- delete end first so line index is not shifted
	vim.cmd(tostring(startBorderLn) .. " delete")
end, { desc = "Delete Surrounding Indentation" })
```

### Yank Surrounding Indentation
Similarly, you can also create a `ysii` command to yank the two lines surrounding
an indentation textobject. (Not using `ysi`, since that blocks surround
commands like `ysi)`). Using `nvim_win_[gs]et_cursor()`, you make the
operation sticky, meaning the cursor is not moved. `vim.highlight.range` is
used to highlight the yanked text, to imitate the effect of `vim.highlight.yank`.

```lua
vim.keymap.set("n", "ysii", function()
	local startPos = vim.api.nvim_win_get_cursor(0)

	-- identify start- and end-border
	require("various-textobjs").indentation("outer", "outer")
	local indentationFound = vim.fn.mode():find("V")
	if not indentationFound then return end
	vim.cmd.normal { "V", bang = true } -- leave visual mode so the `'<` `'>` marks are set

	-- copy them into the + register
	local startLn = vim.api.nvim_buf_get_mark(0, "<")[1] - 1
	local endLn = vim.api.nvim_buf_get_mark(0, ">")[1] - 1
	local startLine = vim.api.nvim_buf_get_lines(0, startLn, startLn + 1, false)[1]
	local endLine = vim.api.nvim_buf_get_lines(0, endLn, endLn + 1, false)[1]
	vim.fn.setreg("+", startLine .. "\n" .. endLine .. "\n")

	-- highlight yanked text
	local ns = vim.api.nvim_create_namespace("ysi")
	vim.highlight.range(0, ns, "IncSearch", { startLn, 0 }, { startLn, -1 })
	vim.highlight.range(0, ns, "IncSearch", { endLn, 0 }, { endLn, -1 })
	vim.defer_fn(function() vim.api.nvim_buf_clear_namespace(0, ns, 0, -1) end, 1000)

	-- restore cursor position
	vim.api.nvim_win_set_cursor(0, startPos)
end, { desc = "Yank surrounding indentation" })
```

### Other Ideas?
If you have some other useful ideas, feel free to [share them in this repo's
discussion
page](https://github.com/chrisgrieser/nvim-various-textobjs/discussions).

## Limitations
- This plugin uses pattern matching, so it can be inaccurate in some edge cases.
- The characterwise textobjects do not match multi-line objects. Most notably,
  this affects the value textobject.

## Other Text Object Plugins
- [treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
- [treesitter-textsubjects](https://github.com/RRethy/nvim-treesitter-textsubjects)
- [ts-hint-textobject](https://github.com/mfussenegger/nvim-ts-hint-textobject)
- [mini.ai](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-ai.md)
- [targets.vim](https://github.com/wellle/targets.vim)

## Credits
**Thanks**  
- To the Valuable Dev for [their blog post on how to get started with creating
  custom text objects](https://thevaluable.dev/vim-create-text-objects/).
- [To `@vypxl` and `@ii14` for figuring out dot-repeatability.](https://github.com/chrisgrieser/nvim-spider/pull/4)

<!-- vale Google.FirstPerson = NO -->
**About Me**  
In my day job, I am a sociologist studying the social mechanisms underlying the
digital economy. For my PhD project, I investigate the governance of the app
economy and how software ecosystems manage the tension between innovation and
compatibility. If you are interested in this subject, feel free to get in touch.

**Blog**  
I also occasionally blog about vim: [Nano Tips for Vim](https://nanotipsforvim.prose.sh)

**Profiles**  
- [Discord](https://discordapp.com/users/462774483044794368/)
- [Academic Website](https://chris-grieser.de/)
- [GitHub](https://github.com/chrisgrieser/)
- [Twitter](https://twitter.com/pseudo_meta)
- [ResearchGate](https://www.researchgate.net/profile/Christopher-Grieser)
- [LinkedIn](https://www.linkedin.com/in/christopher-grieser-ba693b17a/)

<a href='https://ko-fi.com/Y8Y86SQ91' target='_blank'><img
	height='36'
	style='border:0px;height:36px;'
	src='https://cdn.ko-fi.com/cdn/kofi1.png?v=3'
	border='0'
	alt='Buy Me a Coffee at ko-fi.com'
/></a>

[^1]: This respects vim's [quoteescape option](https://neovim.io/doc/user/options.html#'quoteescape').

[^2]: The `lastChange` textobject does not work well with plugins that
	manipulate paste operations such as
	[yanky.nvim](https://github.com/gbprod/yanky.nvim) or plugins that auto-save
	the buffer.

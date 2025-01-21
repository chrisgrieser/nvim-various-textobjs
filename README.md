<!-- LTeX: enabled=false -->
# nvim-various-textobjs 🟪🔷🟡
<!-- LTeX: enabled=true -->
<a href="https://dotfyle.com/plugins/chrisgrieser/nvim-various-textobjs">
<img alt="badge" src="https://dotfyle.com/plugins/chrisgrieser/nvim-various-textobjs/shield"/></a>

Bundle of more than 30 new text objects for Neovim.

## Table of contents

<!-- toc -->

- [List of text objects](#list-of-text-objects)
- [Installation](#installation)
- [Configuration](#configuration)
	* [Options](#options)
	* [Use your own keybindings](#use-your-own-keybindings)
- [Advanced usage / API](#advanced-usage--api)
	* [Go to next occurrence of a text object](#go-to-next-occurrence-of-a-text-object)
	* [`ii` on unindented line should select entire buffer](#ii-on-unindented-line-should-select-entire-buffer)
	* [Smarter `gx`](#smarter-gx)
	* [Delete surrounding indentation](#delete-surrounding-indentation)
	* [Yank surrounding indentation](#yank-surrounding-indentation)
	* [Indent last paste](#indent-last-paste)
	* [Other ideas?](#other-ideas)
- [Limitations & non-goals](#limitations--non-goals)
- [Other text object plugins](#other-text-object-plugins)
- [Credits](#credits)

<!-- tocstop -->

## List of text objects
<!-- LTeX: enabled=false -->

| text object              | description                                                                                                                 | inner / outer                                                                             | forward-seeking    |     default keymaps      | filetypes (for default keymaps) |
| :----------------------- | :-------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------- | :--------------    | :----------------------: | :------------------------------ |
| `indentation`            | surrounding lines with same or higher indentation                                                                           | [see overview from vim-indent-object](https://github.com/michaeljsmith/vim-indent-object) | \-                 | `ii`, `ai`, `aI`, (`iI`) | all                             |
| `restOfIndentation`      | lines downwards with same or higher indentation                                                                             | \-                                                                                        | \-                 |           `R`            | all                             |
| `greedyOuterIndentation` | outer indentation, expanded to blank lines; useful to get functions with annotations                                        | outer includes a blank (like `ap`/`ip`)                                                   | \-                 |        `ag`/`ig`         | all                             |
| `subword`                | segment of a camelCase, snake_case, and kebab-case words                                                                    | outer includes one trailing/leading `_` or `-`                                            | \-                 |        `iS`/`aS`         | all                             |
| `toNextClosingBracket`   | from cursor to next closing `]`, `)`, or `}`, can span multiple lines                                                       | \-                                                                                        | small              |           `C`            | all                             |
| `toNextQuotationMark`    | from cursor to next unescaped `"`, `'`, or `` ` ``, can span multiple lines                                                 | \-                                                                                        | small              |           `Q`            | all                             |
| `anyQuote`               | between any unescaped `"`, `'`, or `` ` `` in one line                                                                      | outer includes the quotation marks                                                        | small              |        `iq`/`aq`         | all                             |
| `anyBracket`             | between any `()`, `[]`, or `{}` in one line                                                                                 | outer includes the brackets                                                               | small              |        `io`/`ao`         | all                             |
| `restOfParagraph`        | like `}`, but linewise                                                                                                      | \-                                                                                        | \-                 |           `r`            | all                             |
| `entireBuffer`           | entire buffer as one text object                                                                                            | \-                                                                                        | \-                 |           `gG`           | all                             |
| `nearEoL`                | from cursor position to end of line minus one character                                                                     | \-                                                                                        | \-                 |           `n`            | all                             |
| `lineCharacterwise`      | current line, but characterwise                                                                                             | outer includes indentation & trailing spaces                                              | small, if on blank |        `i_`/`a_`         | all                             |
| `column`                 | column down until indent or shorter line; accepts `{count}` for multiple columns                                            | \-                                                                                        | \-                 |           `\|`           | all                             |
| `value`                  | value of key-value pair, or right side of assignment, excluding trailing comment (does not work for multi-line assignments) | outer includes trailing `,` or `;`                                                        | small              |        `iv`/`av`         | all                             |
| `key`                    | key of key-value pair, or left side of an assignment                                                                        | outer includes the `=` or `:`                                                             | small              |        `ik`/`ak`         | all                             |
| `url`                    | `http` links or any other protocol                                                                                          | \-                                                                                        | big                |           `L`            | all                             |
| `number`                 | numbers, similar to `<C-a>`                                                                                                 | inner: only digits, outer: number including minus sign and decimal *point*                | small              |        `in`/`an`         | all                             |
| `diagnostic`             | nvim diagnostic                                                                                                             | \-                                                                                        | ∞                  |           `!`            | all                             |
| `closedFold`             | closed fold                                                                                                                 | outer includes one line after the last folded line                                        | big                |        `iz`/`az`         | all                             |
| `chainMember`            | section of a chain connected with `.` (or `:`) like `foo.bar` or `foo.baz(para)`                                            | outer includes the leading `.` (or `:`)                                                   | small              |        `im`/`am`         | all                             |
| `visibleInWindow`        | all lines visible in the current window                                                                                     | \-                                                                                        | \-                 |           `gw`           | all                             |
| `restOfWindow`           | from the cursorline to the last line in the window                                                                          | \-                                                                                        | \-                 |           `gW`           | all                             |
| `lastChange`             | last non-deletion-change, yank, or paste (paste-manipulation plugins may interfere)                                         | \-                                                                                        | \-                 |           `g;`           | all                             |
| `mdLink`                 | markdown link like `[title](url)`                                                                                           | inner is only the link title (between the `[]`)                                           | small              |        `il`/`al`         | markdown, toml                  |
| `mdEmphasis`             | markdown text enclosed by `*`, `**`, `_`, `__`, `~~`, or `==`                                                               | inner is only the emphasis content                                                        | small              |        `ie`/`ae`         | markdown                        |
| `mdFencedCodeBlock`      | markdown fenced code (enclosed by three backticks)                                                                          | outer includes the enclosing backticks                                                    | big                |        `iC`/`aC`         | markdown                        |
| `cssSelector`            | class in CSS such as `.my-class`                                                                                            | outer includes trailing comma and space                                                   | small              |        `ic`/`ac`         | css, scss                       |
| `cssColor`               | color in CSS (hex, rgb, or hsl)                                                                                             | inner includes only the color value                                                       | small              |        `i#`/`a#`         | css, scss                       |
| `htmlAttribute`          | attribute in html/xml like `href="foobar.com"`                                                                              | inner is only the value inside the quotes                                                 | small              |        `ix`/`ax`         | html, xml, css, scss, vue       |
| `doubleSquareBrackets`   | text enclosed by `[[]]`                                                                                                     | outer includes the four square brackets                                                   | small              |        `iD`/`aD`         | lua, shell, neorg, markdown     |
| `shellPipe`              | segment until/after a pipe character (`\|`)                                                                                 | outer includes the pipe                                                                   | small              |        `iP`/`aP`         | bash, zsh, fish, sh             |
| `pyTripleQuotes`         | python strings surrounded by three quotes (regular or f-string); requires python Treesitter parser                          | inner excludes the `"""` or `'''`                                                         | \-                 |        `iy`/`ay`         | python                          |
| `notebookCell`           | cell delimited by [double percent comment][jupytext], such as `# %%`                                                        | outer includes the bottom cell border                                                     | \-                 |        `iN`/`aN`         | all                             |

[jupytext]: https://jupytext.readthedocs.io/en/latest/formats-scripts.html#the-percent-format
<!-- LTeX: enabled=true -->

## Installation
**Variant 1:** Have `nvim-various-textobjs` set up all the keybindings from the
table above for you.

```lua
-- lazy.nvim
{
	"chrisgrieser/nvim-various-textobjs",
	event = "VeryLazy",
	opts = { 
		keymaps = {
			useDefaults = true 
		}
	},
},

-- packer
use {
	"chrisgrieser/nvim-various-textobjs",
	config = function () 
		require("various-textobjs").setup({ 
			keymaps = {
				useDefaults = true 
			}
		})
	end,
}
```

**Variant 2:** Use your own keybindings. See the
[Configuration](#use-your-own-keybindings) section for information on how to set
your own keymaps.

```lua
-- lazy.nvim
{
	"chrisgrieser/nvim-various-textobjs",
	keys = {
		-- ...
	},
},

-- packer
use { "chrisgrieser/nvim-various-textobjs" }
```

> [!TIP]
> You can also use the `keymaps.disabledDefaults` config option to disable
> only *some* default keymaps.

## Configuration

### Options
The `.setup()` call is optional if you do not want to use the default keymaps.

```lua
-- default config
require("various-textobjs").setup {
	keymaps = {
		-- See overview table in README for the defaults. (Note that lazy-loading
		-- this plugin, the default keymaps cannot be set up. if you set this to
		-- `true`, you thus need to add `lazy = false` to your lazy.nvim config.)
		useDefaults = false,

		-- disable only some default keymaps, for example { "ai", "!" }
		-- (only relevant when you set `useDefaults = true`)
		---@type string[]
		disabledDefaults = {},
	},

	forwardLooking = {
		-- Number of lines to seek forwards for a text object. See the overview
		-- table in the README for which text object uses which value.
		small = 5,
		big = 15,
	},
	behavior = {
		-- save position in jumplist when using text objects
		jumplist = true, 
	},

	-- extra configuration for specific text objects
	textobjs = {
		indentation = {
			-- `false`: only indentation decreases delimit the text object
			-- `true`: indentation decreases as well as blank lines serve as delimiter
			blanksAreDelimiter = false,
		},
		subword = {
			-- When deleting the start of a camelCased word, the result should
			-- still be camelCased and not PascalCased (see #113).
			noCamelToPascalCase = true,
		},
		diagnostic = {
			wrap = true,
		},
		url = {
			patterns = {
				[[%l%l%l-://[^%s)%]}"'`]+]], -- exclude ) for md, "'` for strings, } for bibtex
			},
		},
	},

	notify = {
		icon = "󰠱", -- only used with notification plugins like `nvim-notify`
		whenObjectNotFound = true,
	},

	-- show debugging messages on use of certain text objects
	debug = false,
}
```

### Use your own keybindings
If you want to set your own keybindings, you can do so by calling the respective
functions. The function names correspond to the text object names from the
[overview table](#list-of-text-objects).

> [!NOTE]
> For dot-repeat to work, you have to call the motions as Ex-commands. Using
> `function() require("various-textobjs").diagnostic() end` as third argument of
> the keymap will not work.

```lua
-- example: `U` for url textobj
vim.keymap.set({ "o", "x" }, "U", '<cmd>lua require("various-textobjs").url()<CR>')

-- example: `as` for outer subword, `is` for inner subword
vim.keymap.set({ "o", "x" }, "as", '<cmd>lua require("various-textobjs").subword("outer")<CR>')
vim.keymap.set({ "o", "x" }, "is", '<cmd>lua require("various-textobjs").subword("inner")<CR>')
```

For most text objects, there is only one parameter which accepts `"inner"` or
`"outer"`. The only exception is the `indentation` text object:

```lua
-- THE INDENTATION TEXTOBJ requires two parameters, the first for exclusion of 
-- the starting border, the second for the exclusion of ending border
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
```

## Advanced usage / API
All text objects can also be used as an API to modify their behavior or create
custom commands. Here are some examples:

### Go to next occurrence of a text object
When called in normal mode, `nvim-various-textobjs` selects the next occurrence
of the text object. Thus, you can easily create custom motions that go to the
next occurrence of the text object:

```lua
local function gotoNextInnerNumber()
	require("various-textobjs").number("inner")
	local mode = vim.fn.mode()
	if mode:find("[Vv]") then -- only switches to visual when textobj found
		vim.cmd.normal { mode, bang = true } -- leaves visual mode
	end
end,
```

### `ii` on unindented line should select entire buffer
Using a simple if-else-block, you can create a hybrid of the inner indentation
text object and the entire-buffer text object, if you prefer that kind of
behavior:

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
vim.keymap.set("n", "gx", function()
	-- select URL
	require("various-textobjs").url()

	-- plugin only switches to visual mode when textobj is found
	local foundURL = vim.fn.mode() == "v"
	if not foundURL then return end

	-- retrieve URL with the z-register as intermediary
	vim.cmd.normal { '"zy', bang = true }
	local url = vim.fn.getreg("z")
	vim.ui.open(url) -- requires nvim 0.10
end, { desc = "URL Opener" })
```

You could go even further: When no URL can be found by `various-textobjs`, you
could retrieve all URLs in the buffer and select one to open.

```lua
vim.keymap.set("n", "gx", function()
	require("various-textobjs").url()
	local foundURL = vim.fn.mode() == "v"
	if foundURL then
		vim.cmd.normal('"zy')
		local url = vim.fn.getreg("z")
		vim.ui.open(url) -- requires nvim 0.10
		return
	end

	-- find all URLs in buffer
	local urlPattern = [[%l%l%l-://[^%s)"'`]+]]
	local bufText = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
	local urls = {}
	for url in bufText:gmatch(urlPattern) do
		table.insert(urls, url)
	end
	if #urls == 0 then return end

	-- select one
	vim.ui.select(urls, { prompt = "Select URL:" }, function(choice)
		if not choice then return end
		vim.ui.open(url) -- requires nvim 0.10
	end)
end, { desc = "URL Opener" })
```

### Delete surrounding indentation
Using the indentation text object, you can also create custom indentation-related
utilities. A common operation is to remove the line before and after an
indentation. Take for example this case where you are removing the `foo`
condition:

```lua
-- before
if foo then
	print("bar") -- <- cursor is on this line
	print("baz")
end

-- after
print("bar")
print("baz")
```

The code below achieves this by dedenting the inner indentation text object
(essentially running `<ii`), and deleting the two lines surrounding it. As for
the mapping, `dsi` should make sense since this command is similar to the `ds`
operator from [vim-surround](https://github.com/tpope/vim-surround) but
performed on an indentation text object. (It is also an intuitive mnemonic:
Delete Surrounding Indentation.)

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

### Yank surrounding indentation
Similarly, you can also create a `ysii` command to yank the two lines surrounding
an indentation text object. (Not using `ysi`, since that blocks surround
commands like `ysi)`). Using `nvim_win_[gs]et_cursor()`, you make the
operation sticky, meaning the cursor is not moved.

```lua
vim.keymap.set("n", "ysii", function()
	local startPos = vim.api.nvim_win_get_cursor(0)

	-- identify start- and end-border
	require("various-textobjs").indentation("outer", "outer")
	local indentationFound = vim.fn.mode():find("V")
	if not indentationFound then return end
	vim.cmd.normal { "V", bang = true } -- leave visual mode so the '< '> marks are set

	-- copy them into the + register
	local startLn = vim.api.nvim_buf_get_mark(0, "<")[1] - 1
	local endLn = vim.api.nvim_buf_get_mark(0, ">")[1] - 1
	local startLine = vim.api.nvim_buf_get_lines(0, startLn, startLn + 1, false)[1]
	local endLine = vim.api.nvim_buf_get_lines(0, endLn, endLn + 1, false)[1]
	vim.fn.setreg("+", startLine .. "\n" .. endLine .. "\n")

	-- highlight yanked text
	local ns = vim.api.nvim_create_namespace("ysi")
	vim.api.nvim_buf_add_highlight(0, ns, "IncSearch", startLn, 0, -1)
	vim.api.nvim_buf_add_highlight(0, ns, "IncSearch", endLn, 0, -1)
	vim.defer_fn(function() vim.api.nvim_buf_clear_namespace(0, ns, 0, -1) end, 1000)

	-- restore cursor position
	vim.api.nvim_win_set_cursor(0, startPos)
end, { desc = "Yank surrounding indentation" })
```

### Indent last paste
The `lastChange` text object can be used to indent the last text that was pasted.
This is useful in languages such as Python where indentation is meaningful and
thus formatters are not able to automatically indent everything for you.

If you do not use `P` for upwards paste, "shift paste" serves as a great
mnemonic.

```lua
vim.keymap.set("n", "P", function()
	require("various-textobjs").lastChange()
	local changeFound = vim.fn.mode():find("v")
	if changeFound then vim.cmd.normal { ">", bang = true } end
end
```

### Other ideas?
If you have some other useful ideas, feel free to [share them in this repo's
discussion
page](https://github.com/chrisgrieser/nvim-various-textobjs/discussions).

## Limitations & non-goals
- This plugin uses pattern matching, so it can be inaccurate in some edge cases.
- The characterwise text objects do not match multi-line objects. Most notably,
  this affects the value text object.
- [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
  already does an excellent job when it comes to using Treesitter for text
  objects, such as function arguments or loops. This plugin's goal is therefore
  not to provide text objects already offered by `nvim-treesitter-textobjects`.

## Other text object plugins
- [treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
- [treesitter-textsubjects](https://github.com/RRethy/nvim-treesitter-textsubjects)
- [mini.ai](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-ai.md)

## Credits
**Thanks**  
- To the `Valuable Dev` for [their blog post on how to get started with creating
  custom text objects](https://thevaluable.dev/vim-create-text-objects/).
- [To `@vypxl` and `@ii14` for figuring out dot-repeatability.](https://github.com/chrisgrieser/nvim-spider/pull/4)

In my day job, I am a sociologist studying the social mechanisms underlying the
digital economy. For my PhD project, I investigate the governance of the app
economy and how software ecosystems manage the tension between innovation and
compatibility. If you are interested in this subject, feel free to get in touch.

I also occasionally blog about vim: [Nano Tips for Vim](https://nanotipsforvim.prose.sh)

- [Website](https://chris-grieser.de/)
- [Mastodon](https://pkm.social/@pseudometa)
- [ResearchGate](https://www.researchgate.net/profile/Christopher-Grieser)
- [LinkedIn](https://www.linkedin.com/in/christopher-grieser-ba693b17a/)

<a href='https://ko-fi.com/Y8Y86SQ91' target='_blank'><img height='36'
style='border:0px;height:36px;' src='https://cdn.ko-fi.com/cdn/kofi1.png?v=3'
border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>

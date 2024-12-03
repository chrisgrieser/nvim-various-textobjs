<!-- LTeX: enabled=false -->
# nvim-various-textobjs 🟪🔷🟡
<!-- LTeX: enabled=true -->
<a href="https://dotfyle.com/plugins/chrisgrieser/nvim-various-textobjs">
<img alt="badge" src="https://dotfyle.com/plugins/chrisgrieser/nvim-various-textobjs/shield"/></a>

Bundle of more than 30 new textobjects for Neovim.

## Table of contents

<!-- toc -->

- [List of text objects](#list-of-text-objects)
- [Installation](#installation)
- [Configuration](#configuration)
	* [Options](#options)
	* [Use your own keybindings](#use-your-own-keybindings)
- [Advanced usage / API](#advanced-usage--api)
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

| textobject               | description                                                                                | inner / outer                                                                             | forward-seeking |     default keymaps      | filetypes (for default keymaps) |
|:-----------------------  |:-------------------------------------------------------------------------------------------|:------------------------------------------------------------------------------------------|:----------------|:------------------------:|:--------------------------------|
| `indentation`            | surrounding lines with same or higher indentation                                          | [see overview from vim-indent-object](https://github.com/michaeljsmith/vim-indent-object) | \-              | `ii`, `ai`, `aI`, (`iI`) | all                             |
| `restOfIndentation`      | lines down with same or higher indentation                                                 | \-                                                                                        | \-              |           `R`            | all                             |
| `greedyOuterIndentation` | outer indentation, expanded to blank lines; useful to get functions with annotations       | outer includes a blank, like `ap`/`ip`                                                    | \-              |        `ag`/`ig`         | all                             |
| `subword`                | like `iw`, but for segments of camelCase, snake_case, and kebab-case words.                | outer includes trailing `_` or `-`                                                        | \-              |        `iS`/`aS`         | all                             |
| `toNextClosingBracket`   | from cursor to next closing `]`, `)`, or `}`                                               | \-                                                                                        | small           |           `C`            | all                             |
| `toNextQuotationMark`    | from cursor to next unescaped[^1] `"`, `'`, or `` ` ``                                     | \-                                                                                        | small           |           `Q`            | all                             |
| `anyQuote`               | between any unescaped[^1] `"`, `'`, or `` ` `` *in a line*                                 | outer includes the quotation marks                                                        | small           |           `iq`/`aq`      | all                             |
| `anyBracket`             | between any `()`, `[]`, or `{}` *in a line*                                                | outer includes the brackets                                                               | small           |           `io`/`ao`      | all                             |
| `restOfParagraph`        | like `}`, but linewise                                                                     | \-                                                                                        | \-              |           `r`            | all                             |
| `entireBuffer`           | entire buffer as one text object                                                           | \-                                                                                        | \-              |           `gG`           | all                             |
| `nearEoL`                | from cursor position to end of line, minus one character                                   | \-                                                                                        | \-              |           `n`            | all                             |
| `lineCharacterwise`      | current line, but characterwise                                                            | outer includes indentation and trailing spaces                                            | \-              |        `i_`/`a_`         | all                             |
| `column`                 | column down until indent or shorter line. Accepts `{count}` for multiple columns.          | \-                                                                                        | \-              |           `\|`           | all                             |
| `value`                  | value of key-value pair, or right side of assignment, excl. trailing comment (in a line)   | outer includes trailing commas or semicolons                                              | small           |        `iv`/`av`         | all                             |
| `key`                    | key of key-value pair, or left side of an assignment                                       | outer includes the `=` or `:`                                                             | small           |        `ik`/`ak`         | all                             |
| `url`                    | works with `http[s]` or any other protocol                                                 | \-                                                                                        | big             |           `L`            | all                             |
| `number`                 | numbers, similar to `<C-a>`                                                                | inner: only pure digits, outer: number including minus sign and decimal point             | small           |        `in`/`an`         | all                             |
| `diagnostic`             | LSP diagnostic (requires built-in LSP)                                                     | \-                                                                                        | ∞               |           `!`            | all                             |
| `closedFold`             | closed fold                                                                                | outer includes one line after the last folded line                                        | big             |        `iz`/`az`         | all                             |
| `chainMember`            | section of a chain connected with `.` like `foo.bar` or `foo.baz(para)`                    | outer includes the leading `.` (or `:`)                                                   | small           |        `im`/`am`         | all                             |
| `visibleInWindow`        | all lines visible in the current window                                                    | \-                                                                                        | \-              |           `gw`           | all                             |
| `restOfWindow`           | from the cursorline to the last line in the window                                         | \-                                                                                        | \-              |           `gW`           | all                             |
| `lastChange`             | Last non-deletion-change, yank, or paste.[^2]                                              | \-                                                                                        | \-              |           `g;`           | all                             |
| `mdlink`                 | markdown link like `[title](url)`                                                          | inner is only the link title (between the `[]`)                                           | small           |        `il`/`al`         | markdown, toml                  |
| `mdEmphasis`             | markdown text enclosed by `*`, `**`, `_`, `__`, `~~`, or `==`                              | inner is only the emphasis content                                                        | small           |        `ie`/`ae`         | markdown                        |
| `mdFencedCodeBlock`      | markdown fenced code (enclosed by three backticks)                                         | outer includes the enclosing backticks                                                    | big             |        `iC`/`aC`         | markdown                        |
| `cssSelector`            | class in CSS like `.my-class`                                                              | outer includes trailing comma and space                                                   | small           |        `ic`/`ac`         | css, scss                       |
| `cssColor`               | color in CSS (hex, rgb, or hsl)                                                            | inner includes only the color value                                                       | small           |        `i#`/`a#`         | css, scss                       |
| `htmlAttribute`          | attribute in html/xml like `href="foobar.com"`                                             | inner is only the value inside the quotes                                                 | small           |        `ix`/`ax`         | html, xml, css, scss, vue       |
| `doubleSquareBrackets`   | text enclosed by `[[]]`                                                                    | outer includes the four square brackets                                                   | small           |        `iD`/`aD`         | lua, shell, neorg, markdown     |
| `shellPipe`              | segment until/after a pipe character (`\|`)                                                | outer includes the pipe                                                                   | small           |        `iP`/`aP`         | bash, zsh, fish, sh             |
| `pyTripleQuotes`         | python strings surrounded by three quotes (regular or f-string)                            | inner excludes the `"""` or `'''`                                                         | \-              |        `iy`/`ay`         | python                          |
| `notebookCell`           | cell delimited by [double percent comment][jupytext], such as `# %%`                       | outer includes the bottom cell border                                                     | \-              |        `iN`/`aN`         | all                             |

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

**Variant 2:** Use your own keybindings. See the [Configuration](#configuration)
section for information on setting your own keymaps.

```lua
-- lazy.nvim
{
	"chrisgrieser/nvim-various-textobjs",
	lazy = true,
	keys = {
		-- ...
	},
},

-- packer
use { "chrisgrieser/nvim-various-textobjs" }
```

> [!TIP]
> You can also use the `disabledKeymaps` config option to disable only *some*
> default keymaps.

## Configuration

### Options
The `.setup()` call is optional if you are fine with the defaults below.

```lua
-- default config
require("various-textobjs").setup {
	-- set to 0 to only look in the current line
	lookForwardSmall = 5,
	lookForwardBig = 15,

	-- use suggested keymaps (see overview table in README)
	useDefaultKeymaps = false,

	-- disable only some default keymaps, e.g. { "ai", "ii" }
	disabledKeymaps = {},

	-- display notification if a text object is not found
	notifyNotFound = true,

	-- only relevant when using notification plugins like `nvim-notify`
	notificationIcon = "󰠱"
}
```

### Use your own keybindings
If you want to set your own keybindings, you can do so by calling the respective
functions. The function names correspond to the textobject names from the
[overview table](#list-of-text-objects).

> [!NOTE]
> For dot-repeat to work, you have to call the motions as Ex-commands. When
> using `function() require("various-textobjs").diagnostic() end` as third
> argument of the keymap, dot-repeatability is not going to work.

```lua
-- example: `U` for url textobj
vim.keymap.set({ "o", "x" }, "U", '<cmd>lua require("various-textobjs").url()<CR>')

-- example: `as` for outer subword, `is` for inner subword
vim.keymap.set({ "o", "x" }, "as", '<cmd>lua require("various-textobjs").subword("outer")<CR>')
vim.keymap.set({ "o", "x" }, "is", '<cmd>lua require("various-textobjs").subword("inner")<CR>')
```

For most text objects, there is only one parameter which accepts `"inner"` or
`"outer"`. There are two exceptions for that:

```lua
-- 1. THE INDENTATION TEXTOBJ requires two parameters, the first for
-- exclusion of the starting border, the second for the exclusion of ending border
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

-- 2. THE DIAGNOSTIC TEXTOBJ accepts `"wrap"` or `"nowrap"`
vim.keymap.set({ "o", "x" }, "!", '<cmd>lua require("various-textobjs").diagnostic("wrap")<CR>')
```

## Advanced usage / API
All textobjects can also be used as an API to modify their behavior or create
custom commands. Here are some examples:

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
could retrieve all URLs in the buffer and select one to open. (The URL-pattern
used by this plugin is exposed for this purpose.)

```lua
vim.keymap.set("n", "gx", function()
	require("various-textobjs").url()
	local foundURL = vim.fn.mode() == "v"
	if foundURL then
		vim.cmd.normal('"zy')
		local url = vim.fn.getreg("z")
		vim.ui.open(url)
		return
	end

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
		if choice then vim.ui.open(choice) end
	end)
end, { desc = "URL Opener" })
```

### Delete surrounding indentation
Using the indentation textobject, you can also create custom indentation-related
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

The code below achieves this by dedenting the inner indentation textobject
(essentially running `<ii`), and deleting the two lines surrounding it. As for
the mapping, `dsi` should make sense since this command is similar to the `ds`
operator from [vim-surround](https://github.com/tpope/vim-surround) but
performed on an indentation textobject. (It is also an intuitive mnemonic:
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
The `lastChange` textobject can be used to indent the last text that was pasted.
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
- The characterwise textobjects do not match multi-line objects. Most notably,
  this affects the value textobject.
- [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
  already does an excellent job when it comes to using Treesitter for text
  objects, such as function arguments or loops. This plugin's goal is therefore
  not to provide textobjects already offered by `nvim-treesitter-textobjects`.

## Other text object plugins
- [treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
- [treesitter-textsubjects](https://github.com/RRethy/nvim-treesitter-textsubjects)
- [ts-hint-textobject](https://github.com/mfussenegger/nvim-ts-hint-textobject)
- [mini.ai](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-ai.md)
- [targets.vim](https://github.com/wellle/targets.vim)

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

[^1]: This respects vim's [`quoteescape` option](https://neovim.io/doc/user/options.html#'quoteescape').
[^2]: The `lastChange` textobject does not work well with plugins that
	manipulate paste operations such as
	[yanky.nvim](https://github.com/gbprod/yanky.nvim) or plugins that auto-save
	the buffer.

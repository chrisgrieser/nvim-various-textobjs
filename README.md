# nvim-various-textobjs
Bundle of more than a dozen new text objects for Neovim.

<!--toc:start-->
- [List of Text Objects](#list-of-text-objects)
- [Installation](#installation)
- [Configuration](#configuration)
- [Advanced Usage](#advanced-usage)
	- [Smart Alternative to `gx`](#smart-alternative-to-gx)
- [Limitations](#limitations)
- [Other Text-Object Plugins](#other-text-object-plugins)
- [Credits](#credits)
<!--toc:end-->

## List of Text Objects

| textobj              | description                                                                                | inner / outer                                                                             | forward-seeking |     default keymaps      | filetypes (for default keymaps) |
|:---------------------|:-------------------------------------------------------------------------------------------|:------------------------------------------------------------------------------------------|:----------------|:------------------------:|:--------------------------------|
| indentation          | surrounding lines with same or higher indentation                                          | [see overview from vim-indent-object](https://github.com/michaeljsmith/vim-indent-object) | no              | `ii`, `ai`, (`aI`, `iI`) | all                             |
| restOfIndentation    | lines down with same or higher indentation                                                 | \-                                                                                        | no              |           `R`            | all                             |
| subword              | like `iw`, but treating `-`, `_`, and `.` as word delimiters *and* only part of camelCase  | outer includes trailing `_` or `-`                                                        | yes             |        `iS`, `aS`        | all                             |
| toNextClosingBracket | from cursor to next closing `]`, `)`, or `}`                                               | \-                                                                                        | no              |           `%`            | all                             |
| restOfParagraph      | like `}`, but linewise                                                                     | \-                                                                                        | no              |           `r`            | all                             |
| entireBuffer         | entire buffer as one text object                                                           | \-                                                                                        | \-              |           `gG`           | all                             |
| nearEoL              | from cursor position to end of line, minus one character                                   | \-                                                                                        | no              |           `n`            | all                             |
| lineCharacterwise    | current line, but characterwise                                                            | \-                                                                                        | no              |           `_`            | all                             |
| column               | column down until indent or shorter line. Accepts `{count}` for multiple columns.          | \-                                                                                        | no              |     `\|` (pipe char)     | all                             |
| value                | value of key-value pair, or right side of a variable assignment (inside one line)          | outer includes trailing commas or semicolons                                              | yes             |        `iv`, `av`        | all                             |
| key                  | key of key-value pair, or left side of a variable assignment                               | outer includes the `=` or `:`                                                             | yes             |        `ik`, `ak`        | all                             |
| url                  | link beginning with "http"                                                                 | \-                                                                                        | yes             |           `L`            | all                             |
| number (+)           | numbers, similar to `<C-a>`                                                                | inner: only pure digits, outer: number including minus sign and decimal point             | yes             |        `in`, `an`        | all                             |
| diagnostic           | LSP diagnostic (requires built-in LSP)                                                     | \-                                                                                        | yes             |           `!`            | all                             |
| mdlink               | markdown link like `[title](url)`                                                          | inner is only the link title (between the `[]`)                                           | yes             |        `il`, `al`        | markdown, toml                  |
| mdFencedCodeBlock    | markdown fenced code (enclosed by three backticks)                                         | outer includes the enclosing backticks                                                    | yes             |        `iC`, `aC`        | markdown                        |
| cssSelector          | class in CSS, like `.my-class`                                                             | outer includes trailing comma and space                                                   | yes             |        `ic`, `ac`        | css, scss                       |
| jsRegex (+)          | JavaScript regex pattern                                                                   | outer includes the slashes and any flags                                                  | yes             |        `i/`, `a/`        | javascript, typescript          |
| doubleSquareBrackets | text enclosed by `[[]]`                                                                    | outer includes the four square brackets                                                   | yes             |        `iD`, `aD`        | lua, shell, neorg, markdown     |
| shellPipe            | command stdout is piped to                                                                 | outer includes the front pipe character                                                   | yes             |        `iP`/`aP`         | bash, zsh, fish, sh             |

> __Warning__  
> (+) Textobject deprecated due to [treesitter-textobject](https://github.com/nvim-treesitter/nvim-treesitter-textobjects) introducing a similar
textobject that is more capable. 

## Installation

```lua
-- packer
use {
	"chrisgrieser/nvim-various-textobjs",
	config = function () 
		require("various-textobjs").setup({ useDefaultKeymaps = true })
	end,
}

-- lazy.nvim
{
	"chrisgrieser/nvim-various-textobjs",
	config = function () 
		require("various-textobjs").setup({ useDefaultKeymaps = true })
	end,
},
```

## Configuration
The `.setup()` call is optional if you are fine with the defaults below. (Note that the default is to __not__ set any keymaps.)

```lua
-- default config
require("various-textobjs").setup {
	lookForwardLines = 5, -- set to 0 to only look in the current line
	useDefaultKeymaps = false, -- use suggested keymaps (see README)
}
```

---

If you want to set your own keybindings, you can do so by calling the respective functions:
- The function names correspond to the textobj-names from the [overview table](#list-of-text-objects).
- The text objects that differentiate between outer and inner require a boolean parameter, `true` always meaning "inner," and `false` meaning "outer."

```lua
-- example: `?` for diagnostic textobj
vim.keymap.set({"o", "x"}, "?", function () require("various-textobjs").diagnostic() end)

-- example: `an` for outer subword, `in` for inner subword
vim.keymap.set({"o", "x"}, "aS", function () require("various-textobjs").subword(false) end)
vim.keymap.set({"o", "x"}, "iS", function () require("various-textobjs").subword(true) end)

-- exception: indentation textobj requires two parameters, the first for 
-- exclusion of the starting border, the second for the exclusion of ending
-- border
vim.keymap.set({"o", "x"}, "ii", function () require("various-textobjs").indentation(true, true) end)
vim.keymap.set({"o", "x"}, "ai", function () require("various-textobjs").indentation(false, true) end)
```

<details>
<summary>For your convenience, here the code to create mappings for all text objects. You can copypaste this list and enter your own bindings.</summary>

```lua
local keymap = vim.keymap.set
local vt = require("various-textobjs") -- inline this for lazy-loading

keymap( { "o", "x" }, "ii" , function() vt.indentation(true, true) end)
keymap( { "o", "x" }, "ai" , function() vt.indentation(false, true) end)
keymap( { "o", "x" }, "iI" , function() vt.indentation(true, true) end)
keymap( { "o", "x" }, "aI" , function() vt.indentation(false, false) end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.subword(true) end)
keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.subword(false) end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.toNextClosingBracket() end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.restOfParagraph() end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.entireBuffer() end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.nearEoL() end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.lineCharacterwise() end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.column() end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.value(true) end)
keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.value(false) end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.key(true) end)
keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.key(false) end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.url() end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.diagnostic() end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.mdlink(true) end)
keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.mdlink(false) end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.mdFencedCodeBlock(true) end)
keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.mdFencedCodeBlock(false) end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.cssSelector(true) end)
keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.cssSelector(false) end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.doubleSquareBrackets(true) end)
keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.doubleSquareBrackets(false) end)

keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.shellPipe(true) end)
keymap( { "o", "x" }, "YOUR_MAPPING" , function() vt.shellPipe(false) end)
```

</details>

## Advanced Usage

### Smart Alternative to `gx`
Using the URL textobj, you can also write a small snippet to replace netrw's `gx`. The code below retrieves the next URL (within the amount of lines configured in the `setup` call), and opens it in your browser. While this is already an improvement to vim's built-in `gx`, which requires the cursor to be standing on a URL to work, you can even go one step further. If no URL has been found within the next few lines, the `:UrlView` command from [urlview.nvim](https://github.com/axieax/urlview.nvim) is triggered, searching the entire buffer for URLs from which you can choose one to open.

```lua
vim.keymap.set("n", "gx", function ()
	require("various-textobjs").url() -- select URL
	-- this works since the plugin switched to visual mode
	-- if the textobj has been found
	local foundURL = vim.fn.mode():find("v")

	-- if not found in proximity, search whole buffer via urlview.nvim instead
	if not foundURL then
		vim.cmd.UrlView("buffer")
		return
	end
	
	-- retrieve URL with the z-register as intermediary
	vim.cmd.normal { '"zy', bang = true }
	local url = vim.fn.getreg("z")

	-- open with the OS-specific shell command
	local opener
	if vim.fn.has("macunix") == 1 then
		opener = "open"
	elseif vim.fn.has("linux") == 1 then
		opener = "xdg-open"
	elseif vim.fn.has("win64") == 1 or fn.has("win32") == 1 then
		opener = "start"
	end
	local openCommand = string.format ("%s '%s' &>/dev/null", opener, url)
	os.execute(openCommand)
end, {desc = "Smart URL Opener"})
```

## Limitations
- This plugin uses pattern matching, so it can be inaccurate in some edge cases. 
- The value-textobj does not work with multi-line values. 
- There is no reliable dot-repeatability. Any pointers or help on making *text objects* dot-repeatable are welcome. [All plugins/guides I could find implement dot-repeatability only for normal mode mappings and do not work for text objects.](https://github.com/chrisgrieser/nvim-various-textobjs/issues/7#issue-1514404084)

## Other Text-Object Plugins
- [treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
- [treesitter-textsubjects](https://github.com/RRethy/nvim-treesitter-textsubjects)
- [ts-hint-textobject](https://github.com/mfussenegger/nvim-ts-hint-textobject)
- [mini.ai](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-ai.md)
- [targets.vim](https://github.com/wellle/targets.vim)

## Credits
__Thanks__  
Kudos to the Valuable Dev for [their blog post on how to get started with creating custom text objects](https://thevaluable.dev/vim-create-text-objects/).

<!-- vale Google.FirstPerson = NO -->
__About Me__  
In my day job, I am a sociologist studying the social mechanisms underlying the digital economy. For my PhD project, I investigate the governance of the app economy and how software ecosystems manage the tension between innovation and compatibility. If you are interested in this subject, feel free to get in touch.

*Profiles*  
- [Discord](https://discordapp.com/users/462774483044794368/)
- [Academic Website](https://chris-grieser.de/)
- [GitHub](https://github.com/chrisgrieser/)
- [Twitter](https://twitter.com/pseudo_meta)
- [ResearchGate](https://www.researchgate.net/profile/Christopher-Grieser)
- [LinkedIn](https://www.linkedin.com/in/christopher-grieser-ba693b17a/)

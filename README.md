# nvim-various-textobjs
Bundle of more than a dozen new text objects for Neovim.

<!--toc:start-->
- [List of Text Objects](#list-of-text-objects)
- [Installation](#installation)
- [Configuration](#configuration)
- [Advanced Usage](#advanced-usage)
	- [Opening a regex at regex101](#opening-a-regex-at-regex101)
	- [Smart Alternative to `gx`](#smart-alternative-to-gx)
- [Other Text-Object Plugins](#other-text-object-plugins)
- [Roadmap](#roadmap)
- [Credits](#credits)
<!--toc:end-->

## List of Text Objects
| textobj                | description                                                                                   | inner / outer                                                                             | forward-seeking | default keymaps          | filetypes (for default keymaps)   |
|:---------------------- |:--------------------------------------------------------------------------------------------- |:----------------------------------------------------------------------------------------- |:--------------- |:------------------------:|:--------------------------------- |
| indentation            | lines with same amount of indentation                                                         | [see overview from vim-indent-object](https://github.com/michaeljsmith/vim-indent-object) | no              | `ii`, `ia`, `aI`, (`iI`) | all                               |
| value                  | value of key-value pair, or right side of a variable assignment (inside one line)             | outer includes trailing commas or semicolons                                              | yes             | `iv`, `av`               | all                               |
| key                    | key of key-value pair, or left side of a variable assignment                                  | outer includes the `=` or `:`                                                             | yes             | `ik`, `ak`               | all                               |
| number                 | numbers, similar to `<C-a>`                                                                   | inner: only pure digits, outer: number including minus sign and decimal point             | yes             | `in`, `an`               | all                               |
| diagnostic             | LSP diagnostic (requires built-in LSP)                                                        | -                                                                                         | yes             | `!`                      | all                               |
| nearEoL                | from cursor position to end of line, minus one character                                      | -                                                                                         | no              | `n`                      | all                               |
| mdlink                 | markdown link like `[title](url)`                                                             | inner is only the link title (between the `[]`)                                           | yes             | `il`, `al`               | markdown, toml                    |
| mdFencedCodeBlock      | markdown fenced code (enclosed by three backticks)                                            | outer includes the enclosing backticks                                                    | yes             | `iC`, `aC`               | markdown                          |
| cssSelector            | class in CSS, like `.my-class`                                                                | outer includes trailing comma and space                                                   | yes             | `ic`, `ac`               | css, scss                         |,
| jsRegex                | JavaScript regex pattern                                                                      | outer includes the slashes and any flags                                                  | yes             | `i/`, `a/`               | javascript, typescript            |
| doubleSquareBrackets   | text enclosed by `[[]]`                                                                       | outer includes the four square brackets                                                   | yes             | `iD`, `aD`               | lua, shell, neorg, markdown       |
| column                 | column down until indent or shorter line. Accepts `{count}` for multiple columns.             | -                                                                                         | no              | `\|` (pipe char)         | all                               |
| restOfParagraph        | like `}`, but linewise                                                                        | -                                                                                         | no              | `r`                      | all                               |
| subword                | like `iw`, but treating `-`, `_` or `.` as word delimiters *and* only part of camelcase.      | analog to `iw` / `aw`                                                                     | yes             | `iS`, `aS`               | all                               |
| entireBuffer           | entire buffer as one text object                                                              | -                                                                                         | -               | `gG`                     | all                               |
| url                    | URL beginning with "http"                                                                     | -                                                                                         | yes             | `U`                      | all                               |

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
The `.setup()` call is optional if you are fine with the defaults below. (Note that the default is to not set any keymaps by this plugin.)

```lua
-- default config
require("various-textobjs").setup {
	lookForwardLines = 5, -- Set to 0 to only look in the current line.
	useDefaultKeymaps = false, -- Use suggested keymaps (see README).
}
```

---

If you want to set your own keybindings yourself, you can do so by calling the respective function:
- The function names correspond to the textobj-names from the [overview table](#list-of-text-objects).
- The text objects that differentiate between outer and inner require a boolean parameter, `true` always meaning "inner," and `false` meaning "outer."

```lua
-- example: `?` for diagnostic textobj
vim.keymap.set({"o", "x"}, "?", function () require("various-textobjs").diagnostic() end)

-- example: `an` for outer number, `in` for inner number
vim.keymap.set({"o", "x"}, "an", function () require("various-textobjs").number(false) end)
vim.keymap.set({"o", "x"}, "in", function () require("various-textobjs").number(true) end)

-- exception: indentation textobj requires two parameters, first for exclusion of the 
-- starting border, second for the exclusion of ending border
vim.keymap.set({"o", "x"}, "ii", function () require("various-textobjs").indentation(true, true) end)
vim.keymap.set({"o", "x"}, "ai", function () require("various-textobjs").indentation(false, true) end)
```

## Advanced Usage

### Opening a regex at regex101
You can also use the text objects as input for small snippets by yanking them and using `getreg()`. The following example uses the outer regex text object to retrieve pattern, flags, and replacement value of the next regex, and opens [regex101](https://regex101.com/) prefilled with them:

```lua
vim.keymap.set("n", "gR", function()
	require("various-textobjs").jsRegex(false) -- set visual selection to outer regex
	vim.cmd.normal { '"zy', bang = true } -- retrieve regex with "z as intermediary
	local regex = vim.fn.getreg("z")

	local pattern = regex:match("/(.*)/")
	local flags = regex:match("/.*/(.*)")
	local replacement = fn.getline("."):match('replace ?%(/.*/.*, ?"(.-)"')

	-- https://github.com/firasdib/Regex101/wiki/FAQ#how-to-prefill-the-fields-on-the-interface-via-url
	local url = "https://regex101.com/?regex=" .. pattern .. "&flags=" .. flags
	if replacement then url = url .. "&subst=" .. replacement end

	local opener
	if vim.fn.has("macunix") then
		opener = "open"
	elseif vim.fn.has("unix") then
		opener = "xdg-open"
	elseif vim.fn.has("win64") or fn.has("win32") then
		opener = "start"
	end
	os.execute(opener .. "'" .. url .. "'")
end, { desc = "Open next js regex in regex101" })
```

### Smart Alternative to `gx`
Using the URL textobj, you can also write a small snippet for a smarter `gx`. This snippet retrieves the next URL (within the amount of lines configured in the `setup` call), and opens it in your browser. While this is already an improvement to vim's builtin `gx`, which requires the cursor to be standing on an URL to work, you can go one step further: if no URL has been found within the next few lines, the `:UrlView` command from [urlview.nvim](https://github.com/axieax/urlview.nvim) is triggered, searching the entire buffer for a URL to open. 

```lua
vim.keymap.set("n", "gx", function ()
	require("various-textobjs").url() -- select URL
	local foundURL = fn.mode():find("v") -- only switches to visual mode if found
	local url
	if foundURL then
		vim.cmd.normal { '"zy', bang = true } -- retrieve URL with "z as intermediary
		url = fn.getreg("z")

		local opener
		if vim.fn.has("macunix") then
			opener = "open"
		elseif vim.fn.has("unix") then
			opener = "xdg-open"
		elseif vim.fn.has("win64") or fn.has("win32") then
			opener = "start"
		end
		os.execute(opener .. "'" .. url .. "'")
	else
		-- if not found in proximity, search whole buffer via urlview.nvim instead
		cmd.UrlView("buffer")
	end
end, {desc = "Smart URL Opener"})

```

## Other Text-Object Plugins
- [treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
- [treesitter-textsubjects](https://github.com/RRethy/nvim-treesitter-textsubjects)
- [ts-hint-textobject](https://github.com/mfussenegger/nvim-ts-hint-textobject)
- [mini.ai](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-ai.md)
- [targets.vim](https://github.com/wellle/targets.vim)

## Roadmap
- [ ] dot-repeatability ([See also this issue.](https://github.com/chrisgrieser/nvim-various-textobjs/issues/7#issue-1514404084))
- [ ] use treesitter for some textobjs

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

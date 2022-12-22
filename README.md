# nvim-various-textobjs
Bundle of about a dozen custom text objects for Neovim. Includes text objects for: indentation, number, value, diagnostic, markdown link, double square bracket, and many more.

<!--toc:start-->
- [List of Text Objects](#list-of-text-objects)
- [Installation and Setup](#installation-and-setup)
- [Advanced Usage](#advanced-usage)
- [Roadmap](#roadmap)
- [Credits](#credits)
- [About me](#about-me)
<!--toc:end-->

## List of Text Objects
- `.indentation(noStartBorder, noEndBorder)`: Indentation text object. Similar to [vim-indent-object](https://github.com/michaeljsmith/vim-indent-object), The two Boolean parameters determine whether the line in front is included (`aI` or `ai`). Setting both to `false` results in no border inclusion (`ii`).
- `.value(inner)`: Value of a key-value-pair, or the <!-- vale RedHat.TermsErrors = NO --> right-hand-side of a variable assignment. Looks for the first `:` or `=` in the line. Inner value excludes trailing comma or semicolon, outer value includes them. Always excludes trailing comments. \*
- `.number(inner)`: Number text object. Inner number excludes decimal points and minus sign, outer number includes them. \*
- `.diagnostic()`: Diagnostic from the built-in LSP. Similar to [textobj-diagnostic.nvim](https://github.com/andrewferrier/textobj-diagnostic.nvim). \*
- `.subword()`: like `iw`, but treating dashes, underscores, and dots *always* as word delimiters, regardless of the `iskeyword` option.
- `.nearEoL()`: from cursor position to end of line minus 1 character. Useful to change everything except a trailing comma or semicolon.
- `.restOfParagraph()`: like `}`, but linewise.

__FileType specific__
- `.mdlink(inner)`: Markdown link like `[title](url)`. Inner link only includes the link title inside the `[]`. \*
- `.mdFencedCodeBlock(inner)`: Markdown code block enclosed by three backticks. Inner code block excludes the backticks, outer includes them. \*
- `.jsRegex(inner)`: JavaScript regex like `/exp/`. Inner regex excludes the surrounding `/`, outer regex includes them and any flags. \* 
- `.cssSelector(inner)`: CSS class selector like `.my-class`. Similar to `iw`, but does not treat `-` as word-delimiter, and only accepts words with leading `.` as selectors. Outer selector includes the comma and space after the selector, if there are any.\*
- `.doubleSquareBrackets(inner)`: text surrounded by `[[` and `]]`. Multi-line strings in lua, conditionals in shell, or wikilinks in note-filetypes. \*

> __Note__  
> Text objects marked with `*` seek up to 5 lines forward if the cursor is not standing on the text object.

## Installation and Setup

```lua
-- packer.nvim
use "chrisgrieser/nvim-various-textobjs"

-- lazy.nvim
"chrisgrieser/nvim-various-textobjs"
```

A `.setup()` call is not required. It is only needed if you want to change the amount of lines below the cursor where the plugin looks for a text object:

```lua
-- default values. Call optional if the default is fine.
require("various-textobjs").setup {
	lookForwardLines = 5, -- set to 0 to only look in the current line
}
```

The plugin comes without any default keybindings. Set keybindings for the textobj you want to have like this. (All parameters are boolean.)

```lua
-- example: `an` for outer number, `in` for inner number
vim.keymap.set({"o", "x"}, "an", function () require("various-textobjs").number(false) end)
vim.keymap.set({"o", "x"}, "in", function () require("various-textobjs").number(true) end)
```

## Advanced Usage
You can also use the text objects as input for small snippets by yanking them and using `getreg()`. The following example uses the outer regex text object to retrieve pattern, flags, and replacement value of the next regex, and opens [regex101](https://regex101.com/) prefilled with them:

```lua
keymap("n", "gR", function()
	require("various-textobjs").jsRegex(false) -- set visual selection to outer regex
	vim.cmd.normal { '"zy', bang = true }
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

## Roadmap
- [ ] Figure out how to make dot-repeatability work. (Pointers are welcome.)

## Credits
Thanks to the Valuable Dev for [their blogpost on how to get started with creating custom text objects](https://thevaluable.dev/vim-create-text-objects/).

<!-- vale Google.FirstPerson = NO -->
## About me
In my day job, I am a sociologist studying the social mechanisms underlying the digital economy. For my PhD project, I investigate the governance of the app economy and how software ecosystems manage the tension between innovation and compatibility. If you are interested in this subject, feel free to get in touch.

__Profiles__
- [Discord](https://discordapp.com/users/462774483044794368/)
- [Academic Website](https://chris-grieser.de/)
- [GitHub](https://github.com/chrisgrieser/)
- [Twitter](https://twitter.com/pseudo_meta)
- [ResearchGate](https://www.researchgate.net/profile/Christopher-Grieser)
- [LinkedIn](https://www.linkedin.com/in/christopher-grieser-ba693b17a/)

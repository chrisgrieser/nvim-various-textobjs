local M = {}
--------------------------------------------------------------------------------

---@param userConfig? VariousTextobjs.Config
function M.setup(userConfig) require("various-textobjs.config.config").setup(userConfig) end

-- DEPRECATION (2025-11-30)
---@param key string
---@return boolean -- key was deprecated
local function deprecations(key)
	local warning = nil
	if key == "mdFencedCodeBlock" then
		warning = "The `mdFencedCodeBlock` textobj is deprecated. "
			.. "Please use `nvim-treesitter-teextobjects`, create a file "
			.. "`./queries/markdown/textobjects.scm` in your config dir with "
			.. "the following content:\n\n"
			.. "```\n"
			.. "; extends\n"
			.. "(fenced_code_block) @codeblock.outer\n"
			.. "(code_fence_content) @codeblock.inner\n"
			.. "```\n"
			.. "Call the textobject via `:TSTextobjectSelect @codeblock.outer`"
	elseif key == "mdLink" then
		warning = "The `mdLink` textobj is deprecated. "
			.. "Please use `nvim-treesitter-teextobjects`, create a file "
			.. "`./queries/markdown_inline/textobjects.scm` in your config dir "
			.. "with the following content:\n\n"
			.. "```\n"
			.. "; extends\n"
			.. "(inline_link) @mdlink.outer\n"
			.. "(link_text) @mdlink.inner\n"
			.. "```\n"
			.. "Call the textobject via `:TSTextobjectSelect @mdlink.inner`"
	elseif key == "mdEmphasis" then
		warning = "The `mdEmphasis` textobj is deprecated. "
			.. "Please use `nvim-treesitter-teextobjects`, create a file "
			.. "`./queries/markdown_inline/textobjects.scm` in your config dir "
			.. "with the following content:\n\n"
			.. "```\n"
			.. "; extends\n"
			.. "(emphasis) @emphasis.outer\n"
			.. "(strong_emphasis) @emphasis.outer\n"
			.. "((strong_emphasis) @emphasis.inner (#offset! @emphasis.inner 0 2 0 -2))\n"
			.. "((emphasis) @emphasis.inner (#offset! @emphasis.inner 0 1 0 -1))\n"
			.. "```\n"
			.. "Call the textobject via `:TSTextobjectSelect @emphasis.inner`"
	elseif key == "cssSelector" then
		warning = "The `cssSelector` textobj is deprecated. "
			.. "Please use `nvim-treesitter-teextobjects`, create a file "
			.. "`./queries/css/textobjects.scm` in your config dir with "
			.. "the following content:\n\n"
			.. "```\n"
			.. "; extends\n"
			.. '(class_selector "." @selector.outer (class_name) @selector.inner @selector.outer)\n'
			.. "```\n"
			.. "Call the textobject via `:TSTextobjectSelect @selector.inner`"
	elseif key == "shellPipe" then
		warning = "The `shellPipe` textobj is deprecated. "
			.. "Please use `nvim-treesitter-teextobjects`, create a file "
			.. "`./queries/{zsh,bash}/textobjects.scm` in your config dir with "
			.. "the following content:\n\n"
			.. "```\n"
			.. "; extends\n"
			.. '(pipeline (command) @pipeline.inner @pipeline.outer "|" @pipeline.outer)\n'
			.. "```\n"
			.. "Call the textobject via `:TSTextobjectSelect @pipeline.inner`"
	elseif key == "htmlAttribute" then
		warning = "The `htmlAttribute` textobj is deprecated. "
			.. "Please use the existing `@attribute.outer` textobj from "
			.. "`nvim-treesitter-teextobjects`."
	end
	if warning then
		require("various-textobjs.utils").warn(warning)
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- KEYMAP AUTO-GENERATION
--------------------------------------------------------------------------------
-- A plain `vim.keymap.set({"o","x"}, "u", vt.url)` (or rhs = "url" string, or
-- `vt.number` for an inner/outer object) automatically generates the full
-- family of direction maps for the base key: the bare `u` seeks in BOTH
-- directions ("nearest"), `nu` (next) / `lu` (last) pin the direction, and
-- objects with inner/outer variants get their `i`/`a` prefixes passed as the
-- scope. Everything else passes straight through to the original
-- `vim.keymap.set`, so non-various-textobjs mappings are untouched.

---default keys for the seeking directions
local defaultDirectionKeys = { forward = "n", backward = "l" }

-- cache for the forwarding closures created by the metatable `__index`, so
-- `vt.url == vt.url` and function rhs in `vim.keymap.set` can be identified
local textobjFnCache = {}

---detect various-textobjs text objects on the rhs of a `vim.keymap.set` call
---@param rhs unknown
---@return string? objName name of the text object (nil when rhs is no textobj)
---@return boolean isScopeObj whether the object has inner/outer variants
local function identifyTextobj(rhs)
	local defaultKeymaps = require("various-textobjs.config.default-keymaps")
	if type(rhs) == "string" then
		local isScopeObj = vim.tbl_contains(vim.tbl_keys(defaultKeymaps.innerOuterMaps), rhs)
		local isKnownObj = isScopeObj or vim.tbl_contains(vim.tbl_keys(defaultKeymaps.oneMaps), rhs)
		if isKnownObj then return rhs, isScopeObj end
		return nil, false
	end
	-- a function: the metatable `__index` below caches its forwarding
	-- closures, so a `vt.url` rhs can be identified by identity
	if type(rhs) == "function" then
		local cached = textobjFnCache[rhs]
		if cached then return cached.objName, cached.isScopeObj end
	end
	return nil, false
end

---Expand a `vim.keymap.set` call whose rhs is a various-textobjs text object
---into the full family of direction maps, and set them.
---@param originalSet function the original `vim.keymap.set`
---@param modes string|string[]
---@param lhs string base key, e.g. `"u"`
---@param objName string name of the text object
---@param isScopeObj boolean whether the object has inner/outer variants
---@param opts table|nil the original `vim.keymap.set` opts
local function setTextobjMaps(originalSet, modes, lhs, objName, isScopeObj, opts)
	local function setMap(newLhs, scope, direction)
		local descParts = {}
		if scope then descParts[#descParts + 1] = scope end
		if direction then descParts[#descParts + 1] = direction end
		descParts[#descParts + 1] = objName .. " textobj"
		local mapOpts = vim.deepcopy(opts or {})
		mapOpts.desc = table.concat(descParts, " ")

		local args = {}
		if isScopeObj and scope then args[#args + 1] = ("'%s'"):format(scope) end
		if direction then args[#args + 1] = ("'%s'"):format(direction) end
		originalSet(
			modes,
			newLhs,
			("<cmd>lua require('various-textobjs').%s(%s)<CR>"):format(objName, table.concat(args, ", ")),
			mapOpts
		)
	end

	-- generate all maps for one prefix (the bare key, or a scope prefix). The
	-- prefixed map itself always seeks in BOTH directions ("nearest") — the
	-- most useful default for a single map; the `n`/`l` prefixed variants
	-- then pin it to forward/backward
	local function generateMaps(prefix, scope)
		setMap(prefix .. lhs, scope, "nearest")
		for direction, dirKey in pairs(defaultDirectionKeys) do
			setMap(prefix .. dirKey .. lhs, scope, direction)
		end
	end

	if isScopeObj then
		generateMaps("i", "inner")
		generateMaps("a", "outer")
	else
		generateMaps("", nil)
		-- mnemonic i/a family for objects without inner/outer
		generateMaps("i", nil)
		generateMaps("a", nil)
	end
end

-- wrap `vim.keymap.set` once, when this plugin is first loaded
if not vim.keymap._variousTextobjsPatched then
	vim.keymap._variousTextobjsPatched = true
	local originalKeymapSet = vim.keymap.set
	---@param modes string|string[]
	---@param lhs string
	---@param rhs string|function|table
	---@param opts? table
	vim.keymap.set = function(modes, lhs, rhs, opts)
		-- only intercept operator-pending / visual mappings for a text object
		local modeList = type(modes) == "string" and { modes } or modes
		if
			type(lhs) == "string"
			and type(modeList) == "table"
			and (vim.list_contains(modeList, "o") or vim.list_contains(modeList, "x"))
			and (opts == nil or type(opts) == "table")
		then
			local objName, isScopeObj = identifyTextobj(rhs)
			if objName then
				setTextobjMaps(originalKeymapSet, modes, lhs, objName, isScopeObj, opts)
				return
			end
		end
		return originalKeymapSet(modes, lhs, rhs, opts)
	end
end

--------------------------------------------------------------------------------
-- redirect calls to this module to the respective submodules
setmetatable(M, {
	__index = function(_, key)
		-- cache the forwarding closure so `vt.url` always returns the same
		-- function (also lets `vim.keymap.set` identify it as a text object)
		local function textobjFn(...)
			if deprecations(key) then return end

			local linewiseObjs = vim.tbl_keys(require("various-textobjs.textobjs.linewise"))
			local charwiseObjs = vim.tbl_keys(require("various-textobjs.textobjs.charwise"))

			local module
			if vim.tbl_contains(linewiseObjs, key) then module = "linewise" end
			if vim.tbl_contains(charwiseObjs, key) then module = "charwise" end
			if key == "column" then module = "blockwise" end
			if key == "diagnostic" then module = "diagnostic" end
			if key == "subword" then module = "subword" end
			if key == "emoji" then module = "emoji" end

			if module then
				require("various-textobjs.textobjs." .. module)[key](...)
			else
				local msg = ("There is no text object called `%s`.\n\n"):format(key)
					.. "Make sure it exists in the list of text objects, and that you haven't misspelled it."
				require("various-textobjs.utils").warn(msg)
			end
		end
		local defaultKeymaps = require("various-textobjs.config.default-keymaps")
		if vim.tbl_contains(vim.tbl_keys(defaultKeymaps.innerOuterMaps), key) then
			textobjFnCache[textobjFn] = { objName = key, isScopeObj = true }
		elseif vim.tbl_contains(vim.tbl_keys(defaultKeymaps.oneMaps), key) then
			textobjFnCache[textobjFn] = { objName = key, isScopeObj = false }
		end
		M[key] = textobjFn
		return textobjFn
	end,
})

--------------------------------------------------------------------------------
return M

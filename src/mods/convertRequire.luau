-- Rewrites Luau string requires, such as `require("@pkg/React")` or
-- `require("./Foo")`, into the instance requires Roblox runs, like
-- `require(script.Parent.Packages.React)`. It replaces darklua's
-- `convert_require` rule with a Roblox target and property indexing.
--
-- A require is resolved the way Luau resolves it on disk. Relative paths and
-- `@self` start from the requiring file, and other aliases come from the
-- nearest `.config.luau` or `.luaurc` above it that defines them. Aliases that
-- point into the home folder (`~`), like Lute's `@std`, aren't read, since
-- that code never reaches Roblox, so a require through one stops with an
-- error. A Rojo sourcemap then says which instance each file
-- becomes, and the require walks from the requiring file's instance to that
-- one.
--
-- It takes four options:
--
-- - `sourcemap`, the path to a sourcemap from `rojo sourcemap`. It defaults to
--   `sourcemap.json`. As in darklua, the file paths inside it are relative to
--   the sourcemap's own folder.
-- - `sourceFolder` and `buildFolder`, for a build that copies the source
--   folder and rewrites the copy. A file under `buildFolder` is resolved as
--   the file at the same place under `sourceFolder`, which is what the
--   sourcemap and the alias configs describe. Leave both out to resolve
--   files where they are.
-- - `ignore`, a comma-separated list of require strings to leave as they
--   are, for requires that only resolve at runtime. An entry ending in `*`
--   matches every require string that starts with the text before it, so
--   `@std/*,./generated/*` skips Lute's standard library and one folder.
--
-- Relative option paths start from the folder `lute transform` runs in. For
-- example, after copying `src` to `dist`:
--
-- ```sh
-- lute transform <package>/src/mods/convertRequire.luau dist -- --sourcemap sourcemap-darklua.json --sourceFolder src --buildFolder dist
-- ```
--
-- Darklua logs a warning and leaves a require alone when it can't resolve it.
-- This mod stops with an error instead, so a build can't ship a require that
-- won't load. List the requires a build expects to leave alone in `ignore`.
--
-- A child whose name isn't a valid identifier, or is a reserved word like
-- `end`, is indexed with `["name"]`, where darklua writes `['name']`.
--
-- Run it with `lute transform <package>/src/mods/convertRequire.luau <files>`.

local fs = require("@std/fs")
local json = require("@std/json")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")
local transformTypes = require("@std/commands/transform/types")
local utils = require("@std/syntax/utils")

local evaluator = require("../lib/evaluator")

type Options = {
	sourcemap: string,
	sourceFolder: string,
	buildFolder: string,
	ignore: string,
}

export type SourcemapNode = {
	name: string,
	filePaths: { string }?,
	children: { SourcemapNode }?,
}

type LuauConfig = {
	aliases: { [unknown]: unknown }?,
}

-- Every path below is absolute and uses `/`. `initialize` fills these in
-- once, so each file doesn't read the sourcemap again.
--
-- `moduleByFile` and `instanceByFolder` give an instance path, the names
-- from the sourcemap's root down, for each module file and for each folder a
-- module sits in.
local moduleByFile: { [string]: { string } } = {}
local instanceByFolder: { [string]: { string } } = {}
local aliasesByFolder: { [string]: { [string]: string } } = {}
local sourceFolder = ""
local buildFolder = ""

-- The `ignore` entries. An exact entry matches one require string, and a
-- prefix entry, written with a trailing `*`, matches every string starting
-- with it.
local ignoredExact: { [string]: true } = {}
local ignoredPrefixes: { string } = {}

local function isIgnored(requirePath: string): boolean
	if ignoredExact[requirePath] then
		return true
	end
	for _, prefix in ignoredPrefixes do
		if requirePath:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function normalize(filePath: string): string
	local unified = filePath:gsub("\\", "/")
	local root = unified:match("^%a:/") or unified:match("^/") or ""
	local parts = {}
	for _, part in unified:sub(#root + 1):split("/") do
		if part == ".." and #parts > 0 and parts[#parts] ~= ".." then
			table.remove(parts)
		elseif part ~= "." and part ~= "" then
			table.insert(parts, part)
		end
	end
	return root .. table.concat(parts, "/")
end

local function dirname(filePath: string): string
	local parent = filePath:match("^(.*)/[^/]*$")
	if parent == nil then
		return filePath
	elseif parent == "" or parent:match("^%a:$") then
		return `{parent}/`
	end
	return parent
end

local function join(base: string, relative: string): string
	return normalize(`{base}/{relative}`)
end

local function absolute(filePath: string): string
	if path.isAbsolute(filePath) then
		return normalize(filePath)
	end
	return join(path.format(process.cwd()), filePath)
end

local function isInit(filePath: string): boolean
	return filePath:match("/init%.[%w%.]+$") ~= nil
end

local function isLuauFile(filePath: string): boolean
	return filePath:match("%.luau?$") ~= nil
end

local function indexSourcemap(node: SourcemapNode, instancePath: { string }, sourcemapFolder: string)
	for _, filePath in node.filePaths or {} do
		local file = join(sourcemapFolder, filePath)
		if isLuauFile(file) then
			moduleByFile[file] = instancePath
			if isInit(file) then
				instanceByFolder[dirname(file)] = instancePath
			end
		end
	end

	for _, child in node.children or {} do
		local childPath = table.clone(instancePath)
		table.insert(childPath, child.name)
		indexSourcemap(child, childPath, sourcemapFolder)

		-- A folder without an init file has no file of its own in the
		-- sourcemap, so it's found through the files directly inside it.
		for _, filePath in child.filePaths or {} do
			local file = join(sourcemapFolder, filePath)
			if isLuauFile(file) and not isInit(file) and instanceByFolder[dirname(file)] == nil then
				instanceByFolder[dirname(file)] = instancePath
			end
		end
	end
end

local function readAliases(folder: string): { [string]: string }
	local cached = aliasesByFolder[folder]
	if cached then
		return cached
	end

	local configPath = join(folder, ".config.luau")
	local luaurcPath = join(folder, ".luaurc")

	local config: LuauConfig? = nil
	if fs.exists(configPath) then
		config = luau.loadModule(configPath).luau
	elseif fs.exists(luaurcPath) then
		config = (json.deserialize(fs.readFileToString(luaurcPath)) :: unknown) :: LuauConfig
	end

	local aliases = {}
	local configAliases: { [unknown]: unknown } = if config and config.aliases then config.aliases else {}
	for name, value in configAliases do
		-- Lute's JSON decoder also tags each object with a key that isn't a
		-- string, so the type checks skip it.
		if typeof(name) == "string" and typeof(value) == "string" and not value:match("^~") then
			aliases[name:lower()] = join(folder, value)
		end
	end

	aliasesByFolder[folder] = aliases
	return aliases
end

-- The nearest config that defines an alias wins, as in Luau.
local function resolveAlias(fromFolder: string, alias: string): string?
	local folder = fromFolder
	while true do
		local target = readAliases(folder)[alias:lower()]
		if target then
			return target
		end
		local parent = dirname(folder)
		if parent == folder then
			return nil
		end
		folder = parent
	end
end

-- Returns the file or folder a require string points at, without extension.
local function resolveRequirePath(requirer: string, requirePath: string): string
	-- Luau resolves a require from the requiring module's path: the file's
	-- path without its extension, or for an init file, its folder, since an
	-- init file stands for the folder. `./` and `../` start from the folder
	-- that holds the module path, which for an init file is its folder's
	-- parent. `@self` starts at the module path itself, so an init file
	-- reaches its own children with it.
	local modulePath = if isInit(requirer) then dirname(requirer) else (requirer:gsub("%.[%w%.]+$", ""))

	local alias, rest = requirePath:match("^@([^/]+)/?(.*)$")
	if alias == "self" and rest then
		return join(modulePath, rest)
	elseif alias and rest then
		local target = resolveAlias(dirname(requirer), alias)
		assert(target, `{requirer}: unknown alias "@{alias}" in require("{requirePath}")`)
		return join(target, rest)
	end

	assert(requirePath:match("^%.%.?/"), `{requirer}: require("{requirePath}") must start with ./, ../ or @`)
	return join(dirname(modulePath), requirePath)
end

local function findInstance(target: string): { string }?
	for _, candidate in
		{
			`{target}.luau`,
			`{target}.lua`,
			`{target}/init.luau`,
			`{target}/init.lua`,
		}
	do
		local instance = moduleByFile[candidate]
		if instance then
			return instance
		end
	end
	return instanceByFolder[target]
end

-- Luau's reserved words, which can't follow a `.` in an index.
local KEYWORDS: { [string]: boolean } = {}
for _, word in
	{
		"and",
		"break",
		"do",
		"else",
		"elseif",
		"end",
		"false",
		"for",
		"function",
		"if",
		"in",
		"local",
		"nil",
		"not",
		"or",
		"repeat",
		"return",
		"then",
		"true",
		"until",
		"while",
	}
do
	KEYWORDS[word] = true
end

local function isIdentifier(name: string): boolean
	return name:match("^[%a_][%w_]*$") ~= nil and not KEYWORDS[name]
end

-- Builds `script.Parent...` from one instance to another.
local function relativeInstancePath(from: { string }, to: { string }): string
	local shared = 0
	while shared < #from and shared < #to and from[shared + 1] == to[shared + 1] do
		shared += 1
	end

	local expression = "script" .. string.rep(".Parent", #from - shared)
	for index = shared + 1, #to do
		local name = to[index]
		expression ..= if isIdentifier(name) then `.{name}` else `[{evaluator.quoteString(name)}]`
	end
	return expression
end

local function configure(options: Options)
	assert((options.sourceFolder == "") == (options.buildFolder == ""), "pass both --sourceFolder and --buildFolder")
	sourceFolder = if options.sourceFolder == "" then "" else absolute(options.sourceFolder)
	buildFolder = if options.buildFolder == "" then "" else absolute(options.buildFolder)

	local sourcemapPath = absolute(options.sourcemap)
	assert(fs.exists(sourcemapPath), `no sourcemap at {sourcemapPath}; generate one with \`rojo sourcemap\``)
	local sourcemap: unknown = json.deserialize(fs.readFileToString(sourcemapPath))

	ignoredExact = {}
	ignoredPrefixes = {}
	for _, rawEntry in options.ignore:split(",") do
		local entry = rawEntry:gsub("^%s+", ""):gsub("%s+$", "")
		if entry == "" then
			continue
		end
		if entry:sub(-1) == "*" then
			table.insert(ignoredPrefixes, entry:sub(1, -2))
		else
			ignoredExact[entry] = true
		end
	end

	moduleByFile = {}
	instanceByFolder = {}
	aliasesByFolder = {}
	indexSourcemap(sourcemap :: SourcemapNode, {}, dirname(sourcemapPath))
end

local function initialize(context: transformTypes.InitializationContext<Options>)
	configure(context.options)
end

-- Maps a file in the build folder back to the source file it was copied from.
local function sourcePath(filePath: string): string
	local file = absolute(filePath)
	if buildFolder ~= "" and file:sub(1, #buildFolder + 1) == `{buildFolder}/` then
		return sourceFolder .. file:sub(#buildFolder + 1)
	end
	return file
end

local function transform(context: transformTypes.Context<Options>): syntaxTypes.Replacements
	local requirer = sourcePath(context.path)
	local requirerInstance = moduleByFile[requirer]

	return query
		.findAllFromRoot(context.parseresult, utils.isRequireCall)
		:filter(function(call)
			-- Luau only resolves a plain string literal, so a backtick
			-- string, even one without `{}` in it, stays as it is.
			local argument = utils.isExprConstantString(call.arguments[1])
			if #call.arguments ~= 1 or argument == nil or argument.quoteStyle == "interp" then
				return false
			end
			local requirePath = evaluator.stringLiteralValue(argument)
			return requirePath ~= nil and not isIgnored(requirePath)
		end)
		:replace(function(call)
			assert(requirerInstance, `{requirer} isn't in the sourcemap, so its requires can't be resolved`)
			-- The literal is decoded, so escapes like `\111` resolve as the
			-- characters they stand for.
			local requirePath =
				evaluator.stringLiteralValue(call.arguments[1] :: syntax.CstExprConstantString) :: string
			local target = resolveRequirePath(requirer, requirePath)
			local instance = findInstance(target)
			assert(instance, `{requirer}: require("{requirePath}") resolves to {target}, which isn't in the sourcemap`)
			return `require({relativeInstancePath(requirerInstance, instance)})`
		end)
end

local migration: transformTypes.Migration = {
	options = {
		{
			kind = "string",
			name = "sourcemap",
			default = "sourcemap.json",
		},
		{
			kind = "string",
			name = "sourceFolder",
			default = "",
		},
		{
			kind = "string",
			name = "buildFolder",
			default = "",
		},
		{
			kind = "string",
			name = "ignore",
			default = "",
		},
	},
	initialize = initialize,
	transform = transform,
}

return table.freeze(migration)

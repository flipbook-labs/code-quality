local parser = require("@std/syntax/parser")
local printer = require("@std/syntax/printer")
local transformTypes = require("@std/commands/transform/types")

type Migration = {
	read options: { transformTypes.ConfigOption }?,
	read initialize: ((context: transformTypes.InitializationContext) -> ())?,
	read transform: transformTypes.Transformer,
}

-- Runs one code mod over a snippet of Luau source and returns the rewritten
-- source, the way `lute transform` would rewrite a file. Code mods freeze the
-- table they return, so this only reads from it.
--
-- `options` stands in for the `-- --name value` arguments after the files.
-- As in `lute transform`, an option left out takes the default the mod
-- declares, and the mod's `initialize` runs before the file is transformed.
-- `filePath` is the path the mod sees for the snippet.
local function transformSource(
	migration: Migration,
	source: string,
	options: { read [string]: string | boolean }?,
	filePath: string?
): string
	local resolvedOptions: { [string]: string | boolean } = {}
	for _, option in migration.options or {} do
		local value = if options then options[option.name] else nil
		if value == nil then
			value = option.default
		end
		assert(value ~= nil, `Missing required option '--{option.name}'`)
		resolvedOptions[option.name] = value
	end
	table.freeze(resolvedOptions)

	if migration.initialize then
		migration.initialize({ options = resolvedOptions })
	end

	local parseresult = parser.parse(source)
	local result = migration.transform({
		path = filePath or "input.luau",
		source = source,
		parseresult = parseresult,
		options = resolvedOptions,
	})

	if typeof(result) == "string" then
		return result
	end

	return printer.printFile(parseresult, result)
end

return transformSource

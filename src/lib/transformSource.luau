local parser = require("@std/syntax/parser")
local printer = require("@std/syntax/printer")
local transformTypes = require("@std/commands/transform/types")

-- Runs one code mod over a snippet of Luau source and returns the rewritten
-- source, the way `lute transform` would rewrite a file. Code mods freeze the
-- table they return, so this only asks to read its `transform`.
local function transformSource(migration: { read transform: transformTypes.Transformer }, source: string): string
	local parseresult = parser.parse(source)
	local result = migration.transform({
		path = "input.luau",
		source = source,
		parseresult = parseresult,
		options = {},
	})

	if typeof(result) == "string" then
		return result
	end

	return printer.printFile(parseresult, result)
end

return transformSource

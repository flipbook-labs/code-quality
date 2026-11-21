local json = require("@std/json")

local Mod = require("./Mod")
local transform = require("./transform")

export type Options = {
	-- The folder the build copied its source from. The sourcemap and the
	-- alias configs describe files here.
	sourceFolder: string,
	-- The folder holding the copies, which the mods rewrite.
	buildFolder: string,
	-- The files and folders inside `buildFolder` to rewrite. Defaults to all
	-- of `buildFolder`.
	paths: { string }?,
	-- A sourcemap from `rojo sourcemap`. Defaults to `sourcemap.json`.
	sourcemap: string?,
	-- Build globals for `injectGlobalValue`, in the shape its `--globals`
	-- option takes. Write `json.null` for a global that should become `nil`,
	-- since a `nil` value drops the key. The step is skipped when this is nil
	-- or empty.
	globals: { [string]: json.Value }?,
	-- Require strings for `convertRequire` to leave alone. An entry ending in
	-- `*` matches every string that starts with it.
	ignore: { string }?,
}

-- These fold constant expressions, such as the values `injectGlobalValue`
-- puts in, and remove the code that can never run. Each one cleans up what
-- the ones before it leave, such as an empty `do ... end` from
-- `removeUnusedIfBranch`.
local CLEANUP_MODS: { Mod.Mod } = {
	Mod.ComputeExpression,
	Mod.RemoveUnusedIfBranch,
	Mod.RemoveUnusedWhile,
	Mod.FilterAfterEarlyReturn,
	Mod.RemoveNilDeclaration,
	Mod.RemoveEmptyDo,
}

-- Turns a build's copy of Luau source into code Roblox can run: it converts
-- string requires, injects the globals, and then runs the cleanup mods. The
-- mods rewrite files in place, so the caller copies its source into
-- `buildFolder` before calling this.
local function build(options: Options)
	local paths = options.paths or { options.buildFolder }

	local convertOptions = {
		sourcemap = options.sourcemap or "sourcemap.json",
		sourceFolder = options.sourceFolder,
		buildFolder = options.buildFolder,
	}
	if options.ignore and #options.ignore > 0 then
		convertOptions.ignore = table.concat(options.ignore, ",")
	end
	transform(Mod.ConvertRequire, paths, convertOptions)

	if options.globals and next(options.globals) ~= nil then
		transform(Mod.InjectGlobalValue, paths, {
			globals = json.serialize(options.globals),
		})
	end

	for _, mod in CLEANUP_MODS do
		transform(mod, paths)
	end
end

return build

local path = require("@std/path")
local process = require("@std/process")

local Mod = require("./Mod")
local rulesPath = require("./rulesPath")

local modsPath = path.join(path.dirname(rulesPath), "mods")

--[[
	Runs one of the code mods over `paths` with `lute transform`, which rewrites
	the files in place. Each entry in `options` becomes a `--name value`
	argument for the mod. The command runs on the same Lute binary as the
	calling script, and the call errors when the mod fails.
]]
local function transform(mod: Mod.Mod, paths: { string }, options: { [string]: string }?)
	local command = {
		path.format(process.execPath()),
		"transform",
		path.format(path.join(modsPath, `{mod}.luau`)),
	}
	table.move(paths, 1, #paths, #command + 1, command)

	if options then
		table.insert(command, "--")
		-- Sorted so the same options always print the same command.
		local names: { string } = {}
		for name in options do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			table.insert(command, `--{name}`)
			table.insert(command, options[name])
		end
	end

	local result = process.run(command, {
		stdio = "inherit",
	})
	if not result.ok then
		error(`{mod} failed on {table.concat(paths, ", ")}`, 2)
	end
end

return transform

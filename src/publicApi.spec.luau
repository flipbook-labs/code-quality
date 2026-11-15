local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local rulesPath = require("./rulesPath")

-- A repo requires the package by name, through a `.luaurc` alias, from its own
-- folder. This spec does the same in a separate Lute process, so it covers the
-- root `init.luau` and the export as well as the path itself. The process runs
-- the same Lute executable as the spec, since a Rokit-managed `lute` command
-- can't pick a version in a folder without a rokit.toml.
test.suite("public API", function(suite)
	suite:case("RULES_PATH is the rules folder when required through an alias", function(assert)
		local packageRoot = path.dirname(path.dirname(rulesPath))
		local consumer = path.join(system.tmpdir(), `code-quality-consumer-{os.time()}-{math.random(1e6)}`)
		fs.createDirectory(consumer, { makeParents = true })
		fs.writeStringToFile(
			path.join(consumer, ".luaurc"),
			json.serialize({ aliases = { CodeQuality = path.format(packageRoot) } })
		)
		fs.writeStringToFile(path.join(consumer, "main.luau"), 'print(require("@CodeQuality").RULES_PATH)')

		local result = process.run(
			{ path.format(process.execPath()), "run", "main.luau" },
			{ cwd = path.format(consumer) }
		)
		fs.removeDirectory(consumer, { recursive = true })

		assert.eq(result.stderr, "")
		assert.eq(result.ok, true)
		assert.eq(result.stdout:gsub("%s+$", ""), rulesPath)
	end)
end)

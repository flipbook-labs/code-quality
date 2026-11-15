-- Runs rules through the real `lute lint` rather than calling them directly,
-- because some failures only happen in Lute's own handling of a violation
-- after the rule returns it.

local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local function runLint(ruleFile: string, source: string): string
	local result = process.run({
		"lute",
		"lint",
		"--no-default-lints",
		"--rules",
		`src/rules/style/{ruleFile}.luau`,
		"--string-input",
		source,
	})
	return result.stdout .. result.stderr
end

test.suite("lute lint", function(suite)
	suite:case("reports `any` inside a table type", function(assert)
		local output = runLint("noAny", "type T = { field: any }")
		assert.strContains(output, "warning[no_any]")
		assert.strNotContains(output, "attempt to index nil")
	end)

	suite:case("reports an unnamed function type inside a table type", function(assert)
		local output = runLint("functionTypeParamNames", "type T = { get: (string) -> number }")
		assert.strContains(output, "warning[function_type_param_names]")
		assert.strNotContains(output, "attempt to index nil")
	end)

	suite:case("reports an `error` property inside a table type", function(assert)
		local output = runLint("noErrorField", "type T = { error: string }")
		assert.strContains(output, "warning[no_error_field]")
		assert.strNotContains(output, "attempt to index nil")
	end)
	suite:case("reports a restricted module path inside a table type", function(assert)
		-- The rule flags nothing without configuration, so this writes a
		-- config file that restricts `game.Foo.Bar`.
		local configPath = path.join(system.tmpdir(), "restricted-module-paths.config.luau")
		fs.writeStringToFile(
			configPath,
			'return { lute = { lint = { ruleconfigs = { restricted_module_paths = { options = { restricted_paths = { ["game.Foo.Bar"] = "Use Baz." } } } } } } }'
		)

		local result = process.run({
			"lute",
			"lint",
			"--no-default-lints",
			"--config",
			path.format(configPath),
			"--rules",
			"src/rules/lints/restrictedModulePaths.luau",
			"--string-input",
			"type T = { f: typeof(game.Foo.Bar) }",
		})
		fs.remove(configPath)

		local output = result.stdout .. result.stderr
		assert.strContains(output, "warning[restricted_module_paths]")
		assert.strNotContains(output, "attempt to index nil")
	end)
end)

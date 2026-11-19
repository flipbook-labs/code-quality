-- Runs rules through the real `lute lint` rather than calling them directly,
-- because some failures only happen in Lute's own handling of a violation
-- after the rule returns it.

local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

-- `rulePath` is relative to `src/rules`, as in `style/noAny`.
local function runLint(rulePath: string, source: string): string
	local result = process.run({
		"lute",
		"lint",
		"--no-default-lints",
		"--rules",
		`src/rules/{rulePath}.luau`,
		"--string-input",
		source,
	})
	return result.stdout .. result.stderr
end

test.suite("lute lint", function(suite)
	suite:case("reports `any` inside a table type", function(assert)
		local output = runLint("style/noAny", "type T = { field: any }")
		assert.strContains(output, "warning[no_any]")
		assert.strNotContains(output, "attempt to index nil")
	end)

	suite:case("reports an unnamed function type inside a table type", function(assert)
		local output = runLint("style/functionTypeParamNames", "type T = { get: (string) -> number }")
		assert.strContains(output, "warning[function_type_param_names]")
		assert.strNotContains(output, "attempt to index nil")
	end)

	suite:case("reports an `error` property inside a table type", function(assert)
		local output = runLint("style/noErrorField", "type T = { error: string }")
		assert.strContains(output, "warning[no_error_field]")
		assert.strNotContains(output, "attempt to index nil")
	end)
	suite:case("reports an inline table type nested in another", function(assert)
		local output =
			runLint("style/inlineTable", "type T = {\n\tinner: { a: number, b: number, c: number, d: number },\n}")
		assert.strContains(output, "warning[inline_table]")
		assert.strNotContains(output, "attempt to index nil")
	end)

	suite:case("reports a restricted module path inside a table type", function(assert)
		-- The rule flags nothing without configuration, so this writes a
		-- config file that restricts `game.Foo.Bar`.
		-- Each run gets its own file, so overlapping runs don't delete each other's.
		local configPath =
			path.join(system.tmpdir(), `restricted-module-paths-{os.time()}-{math.random(1e9)}.config.luau`)
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

	-- A function inside `typeof` puts whole statements inside a table type.
	local FUNCTION_IN_TABLE_TYPE =
		"type T = { f: typeof(function() local a, b = 1 while true do end a() b() for i = #x, 1 do end end) }"

	for _, case in
		{
			{ rule = "unbalancedAssignments", name = "unbalanced_assignments" },
			{ rule = "emptyLoop", name = "empty_loop" },
			{ rule = "multipleStatements", name = "multiple_statements" },
			{ rule = "suspiciousReverseLoop", name = "suspicious_reverse_loop" },
		}
	do
		suite:case(`reports {case.name} inside a table type`, function(assert)
			local output = runLint(`lints/{case.rule}`, FUNCTION_IN_TABLE_TYPE)
			assert.strContains(output, `warning[{case.name}]`)
			assert.strNotContains(output, "attempt to index nil")
		end)
	end
end)

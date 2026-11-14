-- Runs rules through the real `lute lint` rather than calling them directly,
-- because some failures only happen in Lute's own handling of a violation
-- after the rule returns it.

local process = require("@std/process")
local test = require("@std/test")

local function runLint(ruleName: string, source: string): string
	local result = process.run({
		"lute",
		"lint",
		"--no-default-lints",
		"--rules",
		`src/rules/{ruleName}.luau`,
		"--string-input",
		source,
	})
	return result.stdout .. result.stderr
end

test.suite("lute lint", function(suite)
	suite:case("reports `any` inside a table type", function(assert)
		local output = runLint("no_any", "type T = { field: any }")
		assert.strContains(output, "warning[no_any]")
		assert.strNotContains(output, "attempt to index nil")
	end)

	suite:case("reports an unnamed function type inside a table type", function(assert)
		local output = runLint("function_type_param_names", "type T = { get: (string) -> number }")
		assert.strContains(output, "warning[function_type_param_names]")
		assert.strNotContains(output, "attempt to index nil")
	end)

	suite:case("reports an `error` property inside a table type", function(assert)
		local output = runLint("no_error_field", "type T = { error: string }")
		assert.strContains(output, "warning[no_error_field]")
		assert.strNotContains(output, "attempt to index nil")
	end)
end)

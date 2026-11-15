-- Runs rules through the real `lute lint` rather than calling them directly,
-- because some failures only happen in Lute's own handling of a violation
-- after the rule returns it.

local process = require("@std/process")
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

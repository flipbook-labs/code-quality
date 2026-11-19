local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./noErrorField")

test.suite("no_error_field", function(suite)
	suite:case("flags an `error` field in a table constructor", function(assert)
		assert.eq(#lintSource(rule, "return {\n\tok = false,\n\terror = message,\n}"), 1)
	end)

	suite:case("flags a bracketed `error` key in a table constructor", function(assert)
		assert.eq(#lintSource(rule, 'return {\n\tok = false,\n\t["error"] = message,\n}'), 1)
	end)

	suite:case("leaves other bracketed keys alone", function(assert)
		assert.eq(#lintSource(rule, 'return {\n\t["err"] = message,\n\t[key] = value,\n}'), 0)
	end)

	suite:case("flags an `error` property in a table type", function(assert)
		assert.eq(#lintSource(rule, "type Result = {\n\tok: boolean,\n\terror: string?,\n}"), 1)
	end)

	suite:case("leaves `err` and `problem` alone", function(assert)
		assert.eq(#lintSource(rule, "return {\n\terr = message,\n\tproblem = reason,\n}"), 0)
	end)

	suite:case("leaves calls to the global `error` function alone", function(assert)
		assert.eq(#lintSource(rule, 'error("boom")'), 0)
	end)
end)

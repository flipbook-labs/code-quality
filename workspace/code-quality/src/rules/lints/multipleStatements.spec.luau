local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./multipleStatements")

test.suite("multiple_statements", function(suite)
	suite:case("flags statements sharing a line", function(assert)
		assert.eq(#lintSource(rule, "a() b()"), 1)
		assert.eq(#lintSource(rule, "a(); b(); c()"), 2)
	end)

	suite:case("flags statements inside a one-line function", function(assert)
		local source = table.concat({
			"table.sort(stuff, function(a, b)",
			"    local sum = a + b",
			"    return math.abs(sum) > 2",
			"end)",
			"",
			"table.sort(stuff, function(a, b) local sum = a + b return math.abs(sum) > 2 end)",
		}, "\n")
		assert.eq(#lintSource(rule, source), 2)
	end)

	suite:case("compares the lines statements end on", function(assert)
		assert.eq(#lintSource(rule, "a({\n}) b()"), 1)
		assert.eq(#lintSource(rule, "a()\nb({\n})"), 0)
	end)

	suite:case("allows a one-line if that only returns or breaks by default", function(assert)
		assert.eq(#lintSource(rule, "if true then return end"), 0)
		assert.eq(#lintSource(rule, "if true then return foo() end"), 0)
	end)

	suite:case("flags a one-line if with another statement by default", function(assert)
		assert.eq(#lintSource(rule, "if true then foo() end"), 1)
	end)

	suite:case("allows any one-line if body with one_line_if = allow", function(assert)
		local options = { one_line_if = "allow" }
		assert.eq(#lintSource(rule, "if true then foo() end", options), 0)
		assert.eq(#lintSource(rule, "if true then foo() bar() end", options), 1)
	end)

	suite:case("flags every one-line if with one_line_if = deny", function(assert)
		assert.eq(#lintSource(rule, "if true then return end", { one_line_if = "deny" }), 1)
	end)

	suite:case("leaves one statement per line alone", function(assert)
		assert.eq(#lintSource(rule, "local a = 1\nlocal b = 2\nif a then\n\tb = 3\nend"), 0)
	end)
end)

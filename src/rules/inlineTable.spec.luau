local test = require("@std/test")

local lintSource = require("../lib/lintSource")
local rule = require("./inlineTable")

test.suite("inline_table", function(suite)
	suite:case("flags three keyed fields on one line", function(assert)
		assert.eq(#lintSource(rule, "local t = { a = 1, b = 2, c = 3 }"), 1)
	end)

	suite:case("counts bracketed keys as keyed fields", function(assert)
		assert.eq(#lintSource(rule, 'local t = { a = 1, ["b"] = 2, [3] = 3 }'), 1)
	end)

	suite:case("flags an inline table in a return statement", function(assert)
		assert.eq(#lintSource(rule, "return { a = a, b = b, c = c }"), 1)
	end)

	suite:case("flags a returned table with a single keyed field", function(assert)
		assert.eq(#lintSource(rule, "return { ok = true }"), 1)
	end)

	suite:case("flags a returned table wrapped in a cast or parentheses", function(assert)
		assert.eq(#lintSource(rule, "return { ok = true } :: Result"), 1)
		assert.eq(#lintSource(rule, "return ({ ok = true })"), 1)
	end)

	suite:case("leaves a returned list of values alone", function(assert)
		assert.eq(#lintSource(rule, "return { a, b }"), 0)
	end)

	suite:case("leaves two keyed fields on one line alone", function(assert)
		assert.eq(#lintSource(rule, "local t = { a = 1, b = 2 }"), 0)
	end)

	suite:case("leaves a list of values on one line alone", function(assert)
		assert.eq(#lintSource(rule, 'local t = { "a", "b", "c", "d" }'), 0)
	end)

	suite:case("leaves an expanded table alone", function(assert)
		assert.eq(#lintSource(rule, "local t = {\n\ta = 1,\n\tb = 2,\n\tc = 3,\n}"), 0)
	end)
end)

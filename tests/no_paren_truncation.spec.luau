local test = require("@std/test")

local lintSource = require("./lib/lintSource")
local rule = require("@repo/src/rules/no_paren_truncation")

test.suite("no_paren_truncation", function(suite)
	suite:case("flags a parenthesized method call", function(assert)
		assert.eq(#lintSource(rule, "return (text:gsub('%s', ''))"), 1)
	end)

	suite:case("flags a parenthesized call used as an argument", function(assert)
		assert.eq(#lintSource(rule, "print((string.gsub(text, 'a', 'b')))"), 1)
	end)

	suite:case("flags a call in nested parentheses once", function(assert)
		assert.eq(#lintSource(rule, "return ((f()))"), 1)
	end)

	suite:case("flags a parenthesized call at the end of a table list", function(assert)
		assert.eq(#lintSource(rule, "local parts = { first, (f()) }"), 1)
	end)

	suite:case("flags a parenthesized call assigned to several variables", function(assert)
		assert.eq(#lintSource(rule, "local a, b = (f())"), 1)
	end)

	suite:case("leaves parentheses that don't change the value count alone", function(assert)
		local source = table.concat({
			"local value = (f())",
			"if (f()) then end",
			"local total = (f()) + 1",
			"print((f()), other)",
		}, "\n")
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves parentheses around other expressions alone", function(assert)
		assert.eq(#lintSource(rule, "local total = (a + b) * c"), 0)
	end)

	suite:case("leaves a bare call alone", function(assert)
		assert.eq(#lintSource(rule, "local trimmed = text:gsub('%s', '')"), 0)
	end)
end)

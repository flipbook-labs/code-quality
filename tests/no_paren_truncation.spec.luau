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

	suite:case("leaves parentheses around other expressions alone", function(assert)
		assert.eq(#lintSource(rule, "local total = (a + b) * c"), 0)
	end)

	suite:case("leaves a bare call alone", function(assert)
		assert.eq(#lintSource(rule, "local trimmed = text:gsub('%s', '')"), 0)
	end)
end)

local test = require("@std/test")

local lintSource = require("./lib/lintSource")
local rule = require("@repo/src/rules/tostring_in_interpolation")

test.suite("tostring_in_interpolation", function(suite)
	suite:case("flags `tostring` around an interpolated value", function(assert)
		assert.eq(#lintSource(rule, "local message = `got {tostring(value)}`"), 1)
	end)

	suite:case("suggests the bare value as the fix", function(assert)
		local violations = lintSource(rule, "local message = `got {tostring(count + 1)}`")
		local fix = violations[1].suggestedfix
		assert.eq(if fix then fix.fix else nil, "count + 1")
	end)

	suite:case("leaves bare interpolated values alone", function(assert)
		assert.eq(#lintSource(rule, "local message = `got {value}`"), 0)
	end)

	suite:case("leaves `tostring` outside interpolation alone", function(assert)
		assert.eq(#lintSource(rule, "local text = tostring(value)"), 0)
	end)

	suite:case("leaves `tostring` with a base argument alone", function(assert)
		assert.eq(#lintSource(rule, "local message = `got {tostring(a, b)}`"), 0)
	end)
end)

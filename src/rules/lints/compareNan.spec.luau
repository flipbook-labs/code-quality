local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./compareNan")

test.suite("compare_nan", function(suite)
	suite:case("flags a variable compared to 0/0", function(assert)
		local violations = lintSource(rule, "local _ = x == 0/0")
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "`x ~= x`")
	end)

	suite:case("suggests == for ~=", function(assert)
		local violations = lintSource(rule, "if x ~= 0/0 then end")
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "`x == x`")
	end)

	suite:case("flags locals and indexed variables", function(assert)
		local source = table.concat({
			"local x = 1",
			"local _ = x == 0/0",
			"local _ = a.b == 0/0",
			"local _ = a[1] ~= 0/0",
		}, "\n")
		assert.eq(#lintSource(rule, source), 3)
	end)

	suite:case("leaves other operators alone", function(assert)
		assert.eq(#lintSource(rule, "local _ = x >= 0/0"), 0)
		assert.eq(#lintSource(rule, "local _ = 3 + 0/0"), 0)
	end)

	suite:case("leaves literals and calls on the left alone", function(assert)
		assert.eq(#lintSource(rule, "local _ = 1 ~= 0/0"), 0)
		assert.eq(#lintSource(rule, "local _ = y.foo() == 0/0"), 0)
	end)

	suite:case("leaves NaN on the left alone", function(assert)
		assert.eq(#lintSource(rule, "local _ = 0/0 == x"), 0)
	end)

	suite:case("leaves self-comparison and ordinary comparisons alone", function(assert)
		assert.eq(#lintSource(rule, "local _ = x ~= x"), 0)
		assert.eq(#lintSource(rule, "local _ = x == 1"), 0)
		assert.eq(#lintSource(rule, "local _ = 1 == 0"), 0)
	end)
end)

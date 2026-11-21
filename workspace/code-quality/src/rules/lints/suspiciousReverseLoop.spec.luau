local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./suspiciousReverseLoop")

test.suite("suspicious_reverse_loop", function(suite)
	suite:case("flags a loop from a length down to 1 with no step", function(assert)
		assert.eq(#lintSource(rule, "for _ = #x, 1 do end"), 1)
	end)

	suite:case("flags a loop down to 0", function(assert)
		assert.eq(#lintSource(rule, "for _ = #x, 0 do end"), 1)
	end)

	suite:case("leaves a loop with a step alone", function(assert)
		assert.eq(#lintSource(rule, "for _ = #x, 1, -1 do end"), 0)
		assert.eq(#lintSource(rule, "for _ = #x, 1, y do end"), 0)
	end)

	suite:case("leaves a loop up to a larger number alone", function(assert)
		assert.eq(#lintSource(rule, "for _ = #x, 10 do end"), 0)
	end)

	suite:case("leaves a loop that doesn't start from a length alone", function(assert)
		assert.eq(#lintSource(rule, "for _ = 10, 1 do end"), 0)
		assert.eq(#lintSource(rule, "for _ = #x, y do end"), 0)
	end)
end)

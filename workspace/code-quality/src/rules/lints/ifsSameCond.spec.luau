local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./ifsSameCond")

test.suite("ifs_same_cond", function(suite)
	suite:case("flags an elseif that repeats the if condition", function(assert)
		assert.eq(#lintSource(rule, "if x == 1 then elseif x == 1 then end"), 1)
	end)

	suite:case("flags a repeat among the elseif conditions", function(assert)
		assert.eq(#lintSource(rule, "if x == 1 then elseif y == 1 then elseif y == 1 then end"), 1)
	end)

	suite:case("compares conditions ignoring whitespace", function(assert)
		assert.eq(#lintSource(rule, "if t.x then elseif t.x == nil then elseif t . x then end"), 1)
	end)

	suite:case("leaves conditions with side effects alone", function(assert)
		assert.eq(#lintSource(rule, "if foo() then elseif foo() then end"), 0)
	end)

	suite:case("leaves distinct conditions alone", function(assert)
		assert.eq(#lintSource(rule, "if x then elseif y then elseif z then end"), 0)
	end)
end)

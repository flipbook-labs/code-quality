local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./ifSameThenElse")

test.suite("if_same_then_else", function(suite)
	suite:case("flags an elseif block that repeats the if block", function(assert)
		assert.eq(#lintSource(rule, "if a then print(1) elseif b then print(1) end"), 1)
	end)

	suite:case("flags an else block that repeats an earlier block", function(assert)
		assert.eq(#lintSource(rule, "if a then print(1) elseif b then print(2) else print(2) end"), 1)
	end)

	suite:case("flags each repeat against the earlier blocks", function(assert)
		assert.eq(
			#lintSource(rule, "if a then print(1) elseif b then print(2) elseif c then print(2) else print(1) end"),
			2
		)
	end)

	suite:case("ignores whitespace and comments when comparing", function(assert)
		assert.eq(#lintSource(rule, "if a then print( 1 ) elseif b then print(1) -- same\nend"), 1)
	end)

	suite:case("leaves distinct blocks alone", function(assert)
		assert.eq(#lintSource(rule, "if a then print(1) elseif b then print(2) else print(3) end"), 0)
	end)

	suite:case("skips a block that only returns, as Selene does", function(assert)
		assert.eq(#lintSource(rule, "if a then return true elseif b then return true else return false end"), 0)
	end)

	suite:case("skips empty blocks", function(assert)
		assert.eq(#lintSource(rule, "if a then elseif b then else end"), 0)
	end)
end)

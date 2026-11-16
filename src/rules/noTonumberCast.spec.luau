local test = require("@std/test")

local lintSource = require("../lib/lintSource")
local rule = require("./noTonumberCast")

test.suite("no_tonumber_cast", function(suite)
	suite:case("flags a cast on `tonumber`'s result", function(assert)
		assert.eq(#lintSource(rule, "local count = tonumber(text) :: number"), 1)
	end)

	suite:case("flags a cast through parentheses", function(assert)
		assert.eq(#lintSource(rule, "local count = (tonumber(text)) :: number"), 1)
	end)

	suite:case("flags a cast on `tonumber` with a base", function(assert)
		assert.eq(#lintSource(rule, "local count = tonumber(text, 16) :: number"), 1)
	end)

	suite:case("offers no fix", function(assert)
		assert.eq(lintSource(rule, "local count = tonumber(text) :: number")[1].suggestedfix, nil)
	end)

	suite:case("leaves a fallback alone", function(assert)
		assert.eq(#lintSource(rule, "local count = tonumber(text) or 0"), 0)
	end)

	suite:case("leaves a bare `tonumber` alone", function(assert)
		assert.eq(#lintSource(rule, "local count = tonumber(text)"), 0)
	end)

	suite:case("leaves casts on other calls alone", function(assert)
		assert.eq(#lintSource(rule, "local count = parse(text) :: number"), 0)
	end)
end)

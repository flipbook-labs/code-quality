local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./preferGenericIteration")

test.suite("prefer_generic_iteration", function(suite)
	suite:case("flags `pairs`", function(assert)
		assert.eq(#lintSource(rule, "for key, value in pairs(map) do end"), 1)
	end)

	suite:case("flags `ipairs`", function(assert)
		assert.eq(#lintSource(rule, "for index, item in ipairs(list) do end"), 1)
	end)

	suite:case("leaves direct iteration alone", function(assert)
		assert.eq(#lintSource(rule, "for key, value in map do end"), 0)
	end)

	suite:case("leaves other iterator functions alone", function(assert)
		assert.eq(#lintSource(rule, "for word in text:gmatch('%S+') do end"), 0)
	end)
end)

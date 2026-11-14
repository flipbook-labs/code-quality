local test = require("@std/test")

local lintSource = require("./lib/lintSource")
local rule = require("@repo/src/rules/prefer_annotation")

test.suite("prefer_annotation", function(suite)
	suite:case("flags a local initialized with a cast table", function(assert)
		assert.eq(#lintSource(rule, "local items = {} :: { Item }"), 1)
	end)

	suite:case("flags a local initialized with a cast nil", function(assert)
		assert.eq(#lintSource(rule, "local current = nil :: Item?"), 1)
	end)

	suite:case("leaves an annotated local alone", function(assert)
		assert.eq(#lintSource(rule, "local items: { Item } = {}"), 0)
	end)

	suite:case("leaves a cast of a call result alone", function(assert)
		assert.eq(#lintSource(rule, "local module = require(path) :: Module"), 0)
	end)

	suite:case("leaves a cast of a variable alone", function(assert)
		assert.eq(#lintSource(rule, "local narrowed = value :: string"), 0)
	end)
end)

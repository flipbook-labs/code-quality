local test = require("@std/test")

local lintSource = require("../lib/lintSource")
local rule = require("./annotateNilLocal")

test.suite("annotate_nil_local", function(suite)
	suite:case("flags a local set to nil without an annotation", function(assert)
		assert.eq(#lintSource(rule, "local current = nil"), 1)
	end)

	suite:case("flags a local declared without a value", function(assert)
		assert.eq(#lintSource(rule, "local current"), 1)
	end)

	suite:case("flags only the unannotated nil locals in a list", function(assert)
		assert.eq(#lintSource(rule, "local a: string?, b, c = nil, nil, 1"), 1)
	end)

	suite:case("leaves locals filled by a call's extra return values alone", function(assert)
		assert.eq(#lintSource(rule, "local cst, location = parse(source)"), 0)
		assert.eq(#lintSource(rule, "local first, rest = ..."), 0)
	end)

	suite:case("flags locals past the values when the last value isn't a call", function(assert)
		assert.eq(#lintSource(rule, "local a, b = 1"), 1)
	end)

	suite:case("leaves an annotated nil local alone", function(assert)
		assert.eq(#lintSource(rule, "local current: Item? = nil"), 0)
	end)

	suite:case("leaves a local with a value alone", function(assert)
		assert.eq(#lintSource(rule, "local count = 0"), 0)
	end)
end)

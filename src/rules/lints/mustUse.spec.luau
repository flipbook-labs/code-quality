local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./mustUse")

test.suite("must_use", function(suite)
	suite:case("flags a standard library call whose result is discarded", function(assert)
		assert.eq(#lintSource(rule, "math.max(x, y)"), 1)
	end)

	suite:case("reports the called name, not the arguments", function(assert)
		local violations = lintSource(rule, "math.max(x, y)")
		assert.eq(violations[1].location.beginColumn, 1)
		assert.eq(violations[1].location.endColumn, 9)
	end)

	suite:case("flags each function in the list", function(assert)
		local source = table.concat({
			'string.format("%d", n)',
			"table.concat(list)",
			"bit32.band(a, b)",
		}, "\n")
		assert.eq(#lintSource(rule, source), 3)
	end)

	suite:case("flags a Roblox constructor whose result is discarded", function(assert)
		assert.eq(#lintSource(rule, "Vector3.new(1, 2, 3)"), 1)
	end)

	suite:case("flags a call with type arguments", function(assert)
		assert.eq(#lintSource(rule, "table.clone<<{ string }>>(items)"), 1)
	end)

	suite:case("leaves a call whose result is used alone", function(assert)
		local source = table.concat({
			"local m = math.max(x, y)",
			"print(math.max(x, y))",
			"return math.max(x, y)",
		}, "\n")
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves functions outside the standard library alone", function(assert)
		assert.eq(#lintSource(rule, "print(x)"), 0)
		assert.eq(#lintSource(rule, "myModule.max(x, y)"), 0)
	end)

	suite:case("leaves a local that shares a standard library name alone", function(assert)
		local source = table.concat({
			"local math = {}",
			"math.max(x, y)",
		}, "\n")
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("flags a method on a standard library name", function(assert)
		assert.eq(#lintSource(rule, "Enum:GetEnums()"), 1)
	end)
end)

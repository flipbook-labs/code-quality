local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./highCyclomaticComplexity")

test.suite("high_cyclomatic_complexity", function(suite)
	suite:case("counts a function with no branches as 1", function(assert)
		assert.eq(#lintSource(rule, "local function f() return 1 end", { maximum_complexity = 1 }), 0)
	end)

	suite:case("flags a function whose complexity exceeds the maximum", function(assert)
		assert.eq(
			#lintSource(rule, "local function f(x)\n\tif x then return 1 end\nend", { maximum_complexity = 1 }),
			1
		)
	end)

	suite:case("counts and and or", function(assert)
		assert.eq(
			#lintSource(rule, "local function f(a, b)\n\treturn a and b or nil\nend", { maximum_complexity = 2 }),
			1
		)
	end)

	suite:case("reports each function on its own, not nested ones", function(assert)
		local source = "local function outer(x)\n\tlocal function inner(y)\n\t\treturn y\n\tend\n\treturn inner\nend"
		assert.eq(#lintSource(rule, source, { maximum_complexity = 1 }), 0)
	end)

	suite:case("flags anonymous functions", function(assert)
		assert.eq(#lintSource(rule, "local f = function(x) if x then end end", { maximum_complexity = 1 }), 1)
	end)

	suite:case("flags function declarations", function(assert)
		assert.eq(#lintSource(rule, "function t.f(x) if x then end end", { maximum_complexity = 1 }), 1)
	end)

	suite:case("counts loops", function(assert)
		assert.eq(
			#lintSource(
				rule,
				"local function f(xs)\n\tfor _, x in xs do end\n\twhile x do end\nend",
				{ maximum_complexity = 3 }
			),
			0
		)
		assert.eq(
			#lintSource(
				rule,
				"local function f(xs)\n\tfor _, x in xs do end\n\twhile x do end\nend",
				{ maximum_complexity = 2 }
			),
			1
		)
	end)

	suite:case("uses 40 when the option is missing", function(assert)
		assert.eq(#lintSource(rule, "local function f(x)\n\tif x then end\nend"), 0)
	end)

	suite:case("falls back to 40 when the option is not a whole number", function(assert)
		assert.eq(#lintSource(rule, "local function f(x)\n\tif x then end\nend", { maximum_complexity = "low" }), 0)
	end)
end)

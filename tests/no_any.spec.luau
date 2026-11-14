local test = require("@std/test")

local lintSource = require("./lib/lintSource")
local rule = require("@repo/src/rules/no_any")

test.suite("no_any", function(suite)
	suite:case("flags `any` in an annotation", function(assert)
		local violations = lintSource(rule, "local value: any = 1")
		assert.eq(#violations, 1)
		assert.eq(violations[1].lintname, "no_any")
	end)

	suite:case("flags `any` in a cast", function(assert)
		assert.eq(#lintSource(rule, "local value = thing :: any"), 1)
	end)

	suite:case("flags `any` nested inside another type", function(assert)
		assert.eq(#lintSource(rule, "type Map = { [string]: any }"), 1)
	end)

	suite:case("suggests `unknown` as the fix", function(assert)
		local violations = lintSource(rule, "local value: any = 1")
		local fix = violations[1].suggestedfix
		assert.eq(if fix then fix.fix else nil, "unknown")
	end)

	suite:case("leaves `unknown` alone", function(assert)
		assert.eq(#lintSource(rule, "local value: unknown = 1"), 0)
	end)

	suite:case("leaves a module type that happens to be named `any` alone", function(assert)
		assert.eq(#lintSource(rule, "local value: Types.any = 1"), 0)
	end)
end)

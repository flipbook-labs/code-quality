local test = require("@std/test")

local lintSource = require("./lib/lintSource")
local rule = require("@repo/src/rules/function_type_param_names")

test.suite("function_type_param_names", function(suite)
	suite:case("flags a function type with an unnamed parameter", function(assert)
		assert.eq(#lintSource(rule, "type Load = (ModuleScript) -> ()"), 1)
	end)

	suite:case("flags a function type where only some parameters are named", function(assert)
		assert.eq(#lintSource(rule, "type Set = (key: string, number) -> ()"), 1)
	end)

	suite:case("flags function types inside a table type", function(assert)
		local source = "type Store = {\n\tget: (string) -> number,\n\tset: (string, number) -> (),\n}"
		assert.eq(#lintSource(rule, source), 2)
	end)

	suite:case("leaves fully named parameters alone", function(assert)
		assert.eq(#lintSource(rule, "type Load = (storyModule: ModuleScript) -> ()"), 0)
	end)

	suite:case("leaves a function type with no parameters alone", function(assert)
		assert.eq(#lintSource(rule, "type Callback = () -> ()"), 0)
	end)

	suite:case("leaves a variadic parameter alone", function(assert)
		assert.eq(#lintSource(rule, "type Log = (...string) -> ()"), 0)
	end)
end)

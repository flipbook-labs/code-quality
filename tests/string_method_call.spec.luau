local test = require("@std/test")

local lintSource = require("./lib/lintSource")
local rule = require("@repo/src/rules/string_method_call")

test.suite("string_method_call", function(suite)
	suite:case("flags a string library call on a value", function(assert)
		assert.eq(#lintSource(rule, 'local index = string.find(line, "x")'), 1)
	end)

	suite:case("flags each method in the list", function(assert)
		local source = table.concat({
			"string.lower(name)",
			"string.gsub(content, a, b)",
			"string.split(path, '/')",
			"string.sub(text, 1, 2)",
		}, "\n")
		assert.eq(#lintSource(rule, source), 4)
	end)

	suite:case("leaves colon calls alone", function(assert)
		assert.eq(#lintSource(rule, 'local index = line:find("x")'), 0)
	end)

	suite:case("leaves a call whose first argument is a string literal alone", function(assert)
		assert.eq(#lintSource(rule, 'local divider = string.rep("-", 20)'), 0)
		assert.eq(#lintSource(rule, 'local text = string.format("%d items", count)'), 0)
	end)

	suite:case("leaves string functions that aren't methods alone", function(assert)
		assert.eq(#lintSource(rule, "local letter = string.char(65)"), 0)
	end)

	suite:case("leaves other libraries alone", function(assert)
		assert.eq(#lintSource(rule, "local index = table.find(list, value)"), 0)
	end)
end)

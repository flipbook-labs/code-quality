local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./mixedTable")

test.suite("mixed_table", function(suite)
	suite:case("flags positional then named entries", function(assert)
		assert.eq(#lintSource(rule, 'local bad = { "", a = b }'), 1)
	end)

	suite:case("flags positional then bracketed entries", function(assert)
		assert.eq(#lintSource(rule, "bad = { {}, [a] = b }"), 1)
		assert.eq(#lintSource(rule, 'bad = { a, [""] = b }'), 1)
	end)

	suite:case("flags an explicit numeric key after a positional entry", function(assert)
		assert.eq(#lintSource(rule, "bad = { 1, [2] = b }"), 1)
	end)

	suite:case("flags keyed then positional entries", function(assert)
		assert.eq(#lintSource(rule, 'bad = { [a] = b, [c] = d, "" }'), 1)
	end)

	suite:case("reports each table once", function(assert)
		local violations = lintSource(rule, 'bad({ a = b, "", c = d })')
		assert.eq(#violations, 1)
		assert.eq(violations[1].location.beginColumn, 7)
		assert.eq(violations[1].location.endColumn, 16)
	end)

	suite:case("leaves dictionaries and arrays alone", function(assert)
		assert.eq(#lintSource(rule, "local good = { a = b, c = d }"), 0)
		assert.eq(#lintSource(rule, 'good = { "", a }'), 0)
		assert.eq(#lintSource(rule, "good = { [1] = a, [3] = b }"), 0)
		assert.eq(#lintSource(rule, "good({ a = b, c = d })"), 0)
	end)
end)

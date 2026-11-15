local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./unscopedVariables")

-- Selene's own unscoped_variables fixture. `bar` and `baz` are reported, and
-- the `foo` and `bar` assignments that follow a local declaration are not.
local SELENE_FIXTURE = table.concat({
	"bar = true",
	"",
	"local foo = 1",
	"foo = 2",
	"",
	"local bar = 1",
	"bar = 2",
	"",
	"pcall(function()",
	"    foo = 3",
	"    baz = 1",
	"end)",
	"",
	"_ = 3",
}, "\n")

test.suite("unscoped_variables", function(suite)
	suite:case("matches Selene's fixture", function(assert)
		assert.eq(#lintSource(rule, SELENE_FIXTURE), 2)
	end)

	suite:case("flags an assignment to an undeclared name", function(assert)
		assert.eq(#lintSource(rule, "baz = 1"), 1)
	end)

	suite:case("reports only the first unscoped assignment in a scope", function(assert)
		assert.eq(#lintSource(rule, "baz = 1\nbaz = 2"), 1)
	end)

	suite:case("reports the assignment again from another scope", function(assert)
		local source = table.concat({
			"do",
			"    baz = 1",
			"end",
			"baz = 2",
		}, "\n")
		assert.eq(#lintSource(rule, source), 2)
	end)

	suite:case("leaves assignments to a local alone", function(assert)
		assert.eq(#lintSource(rule, "local foo = 1\nfoo = 2"), 0)
	end)

	suite:case("leaves a read of an undeclared name alone", function(assert)
		assert.eq(#lintSource(rule, "print(baz)"), 0)
	end)

	suite:case("leaves field assignments alone", function(assert)
		assert.eq(#lintSource(rule, "game.name = 'x'"), 0)
	end)

	suite:case("leaves a function declaration on a global table alone", function(assert)
		assert.eq(#lintSource(rule, "function global.name() end"), 0)
	end)

	suite:case("leaves a name matching the default pattern alone", function(assert)
		assert.eq(#lintSource(rule, "_ = 3"), 0)
	end)

	suite:case("honors an ignore_pattern option", function(assert)
		assert.eq(#lintSource(rule, "temp = 1", { ignore_pattern = "^tmp" }), 1)
		assert.eq(#lintSource(rule, "temp = 1", { ignore_pattern = "^temp" }), 0)
	end)
end)

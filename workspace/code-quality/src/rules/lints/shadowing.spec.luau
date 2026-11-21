local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./shadowing")

-- Selene's own shadowing fixture. It shadows `x` twice and `foo` once, and the
-- `_` loop variables are allowed by the default pattern.
local SELENE_FIXTURE = table.concat({
	"local x = 1",
	"",
	"if true then",
	"    x = 2",
	"    local x = 3",
	"    local x = 4",
	"    local y = 3",
	"end",
	"",
	"if true then",
	"    local y = 4",
	"end",
	"",
	"local function foo() end",
	"if true then",
	"    local function foo() end",
	"end",
	"",
	"for _ = 1, 5 do",
	"    for _ = 1, 5 do",
	"    end",
	"end",
}, "\n")

test.suite("shadowing", function(suite)
	suite:case("matches Selene's fixture", function(assert)
		assert.eq(#lintSource(rule, SELENE_FIXTURE), 3)
	end)

	suite:case("flags a local that redeclares a name in the same scope", function(assert)
		assert.eq(#lintSource(rule, "local x = 1\nlocal x = 2"), 1)
	end)

	suite:case("flags a function parameter that shadows a local", function(assert)
		assert.eq(#lintSource(rule, "local value = 1\nlocal function f(value) end"), 1)
	end)

	suite:case("flags a loop variable that shadows a local", function(assert)
		assert.eq(#lintSource(rule, "local i = 1\nfor i = 1, 2 do end"), 1)
		assert.eq(#lintSource(rule, "local k = 1\nfor k in pairs({}) do end"), 1)
	end)

	suite:case("flags a local function that shadows a local", function(assert)
		assert.eq(#lintSource(rule, "local foo = 1\nlocal function foo() end"), 1)
	end)

	suite:case("flags a local that shadows an undeclared global assigned earlier", function(assert)
		assert.eq(#lintSource(rule, "g = 1\nlocal g = 2"), 1)
	end)

	suite:case("flags a method's self when an enclosing self is in scope", function(assert)
		local source = table.concat({
			"local obj = {}",
			"function obj:outer()",
			"    function obj:inner() end",
			"end",
		}, "\n")
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("leaves sibling scopes alone", function(assert)
		assert.eq(#lintSource(rule, "do local x = 1 end\ndo local x = 2 end"), 0)
		assert.eq(#lintSource(rule, "if a then local y = 1 end\nlocal y = 2"), 0)
	end)

	suite:case("flags a nested function's local, but not one declared after the function", function(assert)
		assert.eq(#lintSource(rule, "local x = 1\nlocal function f() local x = 2 end\n"), 1)
		assert.eq(#lintSource(rule, "local function f() local x = 2 end\nlocal x = 1"), 0)
	end)

	suite:case("leaves a function declaration of a visible name alone", function(assert)
		assert.eq(#lintSource(rule, "local foo = 1\nfunction foo() end"), 0)
	end)

	suite:case("leaves a generic type parameter alone", function(assert)
		assert.eq(#lintSource(rule, "local U = 1\nlocal function h<U>(a: U) end"), 0)
	end)

	suite:case("leaves names matching the default pattern alone", function(assert)
		assert.eq(#lintSource(rule, "local _x = 1\nlocal _x = 2"), 0)
	end)

	suite:case("honors an ignore_pattern option", function(assert)
		local source = "local temp = 1\nlocal temp = 2"
		assert.eq(#lintSource(rule, source, { ignore_pattern = "^tmp" }), 1)
		assert.eq(#lintSource(rule, source, { ignore_pattern = "^temp" }), 0)
	end)
end)

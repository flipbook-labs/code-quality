local parser = require("@std/syntax/parser")
local test = require("@std/test")

local exprHasSideEffects = require("./exprHasSideEffects")

local function check(source: string): boolean
	return exprHasSideEffects(parser.parseExpr(source))
end

test.suite("exprHasSideEffects", function(suite)
	suite:case("literals and names are free of side effects", function(assert)
		assert.eq(check("1"), false)
		assert.eq(check("'text'"), false)
		assert.eq(check("nil"), false)
		assert.eq(check("value"), false)
	end)

	suite:case("calls have side effects", function(assert)
		assert.eq(check("f()"), true)
		assert.eq(check("a.b:c()"), true)
	end)

	suite:case("field access looks through to what it indexes", function(assert)
		assert.eq(check("a.b.c"), false)
		assert.eq(check("f().x"), true)
	end)

	suite:case("indexing with a call key is treated as free of side effects, as in Selene", function(assert)
		assert.eq(check("t[f()]"), false)
	end)

	suite:case("operators look at their operands", function(assert)
		assert.eq(check("a == b"), false)
		assert.eq(check("a == f()"), true)
		assert.eq(check("not f()"), true)
	end)

	suite:case("table constructors look at their entries", function(assert)
		assert.eq(check("{ x = 1, y = 2 }"), false)
		assert.eq(check("{ f() }"), true)
		assert.eq(check("{ [f()] = 1 }"), true)
	end)

	suite:case("grouping and casts look through", function(assert)
		assert.eq(check("(a)"), false)
		assert.eq(check("(f() :: any)"), true)
	end)
end)

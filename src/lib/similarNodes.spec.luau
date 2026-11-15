local parser = require("@std/syntax/parser")
local test = require("@std/test")

local similarNodes = require("./similarNodes")

local function firstExpr(source: string)
	return parser.parseExpr(source)
end

test.suite("similarNodes", function(suite)
	suite:case("matches the same expression", function(assert)
		assert.eq(similarNodes(firstExpr("a + b"), firstExpr("a + b")), true)
	end)

	suite:case("ignores whitespace and comments", function(assert)
		assert.eq(similarNodes(firstExpr("f( a,b )"), firstExpr("f(a, --[[x]] b)")), true)
	end)

	suite:case("tells different identifiers apart", function(assert)
		assert.eq(similarNodes(firstExpr("a.b"), firstExpr("a.c")), false)
	end)

	suite:case("tells different string quoting apart", function(assert)
		assert.eq(similarNodes(firstExpr("'a'"), firstExpr('"a"')), false)
	end)

	suite:case("tells different operators apart", function(assert)
		assert.eq(similarNodes(firstExpr("a == b"), firstExpr("a ~= b")), false)
	end)

	suite:case("ignores which binding a name resolves to", function(assert)
		assert.eq(similarNodes(firstExpr("x"), firstExpr("x")), true)
	end)
end)

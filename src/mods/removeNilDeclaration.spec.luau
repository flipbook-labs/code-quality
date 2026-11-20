local test = require("@std/test")

local migration = require("./removeNilDeclaration")
local transformSource = require("../lib/transformSource")

test.suite("removeNilDeclaration code mod", function(suite)
	suite:case("removes nil from a local", function(assert)
		assert.eq(transformSource(migration, "local a = nil\n"), "local a\n")
	end)

	suite:case("keeps the annotation and the comment after it", function(assert)
		assert.eq(
			transformSource(migration, "local a: number? = nil -- set later\n"),
			"local a: number? -- set later\n"
		)
	end)

	suite:case("moves names set to nil to the end", function(assert)
		assert.eq(transformSource(migration, "local a, b = nil, 1\n"), "local b, a = 1\n")
		assert.eq(transformSource(migration, "local a, b, c = 1, nil, 2\n"), "local a, c, b = 1, 2\n")
	end)

	suite:case("wraps a call left last so it sets one name", function(assert)
		assert.eq(transformSource(migration, "local a, b = nil, f()\n"), "local b, a = (f())\n")
		assert.eq(transformSource(migration, "local a, b = f(), nil\n"), "local a, b = (f())\n")
	end)

	suite:case("drops extra values without side effects", function(assert)
		assert.eq(transformSource(migration, "local a = 1, 2\n"), "local a = 1\n")
	end)

	suite:case("keeps extra values with side effects", function(assert)
		local source = "local a = nil, f()\n"
		assert.eq(transformSource(migration, source), source)
	end)

	suite:case("leaves a call that fills the remaining names alone", function(assert)
		local source = "local a, b, c = nil, f()\n"
		assert.eq(transformSource(migration, source), source)
	end)

	suite:case("leaves a name declared twice alone", function(assert)
		local source = "local a, a = nil, 1\n"
		assert.eq(transformSource(migration, source), source)
	end)

	suite:case("leaves nil in parentheses, other values, and const alone", function(assert)
		local source = "local a = (nil)\nlocal b = false\nlocal c\nconst d = nil\na = nil\n"
		assert.eq(transformSource(migration, source), source)
	end)
end)

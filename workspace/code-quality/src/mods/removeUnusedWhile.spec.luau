local test = require("@std/test")

local migration = require("./removeUnusedWhile")
local transformSource = require("../lib/transformSource")

test.suite("removeUnusedWhile code mod", function(suite)
	suite:case("removes a loop whose condition is always false", function(assert)
		assert.eq(transformSource(migration, "a()\nwhile false do\n\tb()\nend\nc()\n"), "a()\nc()\n")
		assert.eq(transformSource(migration, "while nil do end\n"), "")
	end)

	suite:case("folds a condition built from literals", function(assert)
		assert.eq(transformSource(migration, 'while "prod" == "dev" do\n\tb()\nend\n'), "")
		assert.eq(transformSource(migration, "while not true do end\n"), "")
	end)

	suite:case("removes a loop whose condition can't reach its side effect", function(assert)
		assert.eq(transformSource(migration, "while false and f() do end\n"), "")
	end)

	suite:case("leaves loops that might run alone", function(assert)
		local source = table.concat({
			"while true do break end",
			"while running do end",
			"while 0 do break end",
			"while f() do end",
		}, "\n")
		assert.eq(transformSource(migration, source), source)
	end)

	suite:case("keeps a condition with side effects", function(assert)
		local source = "while not { f() } do end"
		assert.eq(transformSource(migration, source), source)
	end)
end)

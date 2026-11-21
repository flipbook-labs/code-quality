local test = require("@std/test")

local migration = require("./filterAfterEarlyReturn")
local transformSource = require("../lib/transformSource")

test.suite("filterAfterEarlyReturn code mod", function(suite)
	suite:case("removes the statements after a block that returns", function(assert)
		local source = "local function f()\n\tdo return end\n\tprint(1)\n\treturn 2\nend\n"
		assert.eq(transformSource(migration, source), "local function f()\n\tdo return end\nend\n")
	end)

	suite:case("removes code after a return at the top of a file", function(assert)
		assert.eq(transformSource(migration, "do\n\treturn 1\nend\nprint(2)\n"), "do\n\treturn 1\nend\n")
	end)

	suite:case("looks inside nested blocks", function(assert)
		local source = "do\n\tdo return end\nend\nprint(1)\n"
		assert.eq(transformSource(migration, source), "do\n\tdo return end\nend\n")
	end)

	suite:case("leaves a block that ends in break or continue alone", function(assert)
		local source =
			"for _ = 1, 2 do\n\tdo break end\n\tprint(1)\nend\nfor _ = 1, 2 do\n\tdo continue end\n\tprint(1)\nend\n"
		assert.eq(transformSource(migration, source), source)
	end)

	suite:case("leaves an if that returns alone, as darklua does", function(assert)
		local source = "if x then return end\nprint(1)\n"
		assert.eq(transformSource(migration, source), source)
	end)
end)

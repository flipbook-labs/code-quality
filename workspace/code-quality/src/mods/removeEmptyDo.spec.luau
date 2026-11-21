local test = require("@std/test")

local migration = require("./removeEmptyDo")
local transformSource = require("../lib/transformSource")

test.suite("removeEmptyDo code mod", function(suite)
	suite:case("removes an empty block", function(assert)
		assert.eq(transformSource(migration, "a()\ndo end\nb()\n"), "a()\nb()\n")
	end)

	suite:case("removes a block that holds only comments", function(assert)
		assert.eq(transformSource(migration, "a()\ndo\n\t-- nothing yet\nend\nb()\n"), "a()\nb()\n")
	end)

	suite:case("removes blocks that hold only empty blocks", function(assert)
		assert.eq(transformSource(migration, "a()\ndo\n\tdo end\nend\nb()\n"), "a()\nb()\n")
	end)

	suite:case("removes empty blocks inside functions and other blocks", function(assert)
		local source = "local function f()\n\tdo end\n\treturn 1\nend\n"
		assert.eq(transformSource(migration, source), "local function f()\n\treturn 1\nend\n")
	end)

	suite:case("leaves blocks with statements alone", function(assert)
		local source = "do\n\tlocal x = 1\nend\nwhile true do end\n"
		assert.eq(transformSource(migration, source), source)
	end)

	suite:case("keeps a statement that opens with ( apart from the one before", function(assert)
		assert.eq(transformSource(migration, "a()\ndo end\n(f or g)()\n"), "a()\n;(f or g)()\n")
	end)
end)

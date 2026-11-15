local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./manualTableClone")

test.suite("manual_table_clone", function(suite)
	suite:case("flags a pairs copy into a fresh table", function(assert)
		assert.eq(#lintSource(rule, "local new = {}\nfor key, value in pairs(stuff) do\n\tnew[key] = value\nend"), 1)
	end)

	suite:case("flags an ipairs copy", function(assert)
		assert.eq(#lintSource(rule, "local new = {}\nfor key, value in ipairs(stuff) do\n\tnew[key] = value\nend"), 1)
	end)

	suite:case("flags a next copy", function(assert)
		assert.eq(#lintSource(rule, "local new = {}\nfor key, value in next, stuff do\n\tnew[key] = value\nend"), 1)
	end)

	suite:case("flags a bare iterable, as Luau allows", function(assert)
		assert.eq(#lintSource(rule, "local new = {}\nfor key, value in stuff do\n\tnew[key] = value\nend"), 1)
	end)

	suite:case("flags a call as the iterable", function(assert)
		assert.eq(
			#lintSource(rule, "local new = {}\nfor key, value in pairs(getStuff()) do\n\tnew[key] = value\nend"),
			1
		)
	end)

	suite:case("flags a copy whose table is used after the loop", function(assert)
		assert.eq(
			#lintSource(
				rule,
				"local new = {}\nfor key, value in pairs(stuff) do\n\tnew[key] = value\nend\nnew.used = 1"
			),
			1
		)
	end)

	suite:case("flags a copy with a statement between the definition and the loop", function(assert)
		assert.eq(
			#lintSource(rule, "local new = {}\nblah()\nfor key, value in pairs(stuff) do\n\tnew[key] = value\nend"),
			1
		)
	end)

	suite:case("leaves a loop whose body does more than copy", function(assert)
		assert.eq(
			#lintSource(
				rule,
				"local new = {}\nfor key, value in pairs(stuff) do\n\tif key == 'a' then new[key] = value end\nend"
			),
			0
		)
	end)

	suite:case("leaves a table that was used before the loop", function(assert)
		assert.eq(
			#lintSource(
				rule,
				"local new = {}\nwhoKnows(new)\nfor key, value in pairs(stuff) do\n\tnew[key] = value\nend"
			),
			0
		)
	end)

	suite:case("leaves a target that is used in the loop head", function(assert)
		assert.eq(#lintSource(rule, "local new = {}\nfor key, value in pairs(new) do\n\tnew[key] = value\nend"), 0)
	end)

	suite:case("leaves a table that already has fields", function(assert)
		assert.eq(
			#lintSource(rule, "local new = { x = 1 }\nfor key, value in pairs(stuff) do\n\tnew[key] = value\nend"),
			0
		)
	end)

	suite:case("leaves a table that a call created", function(assert)
		assert.eq(
			#lintSource(rule, "local new = whoKnows()\nfor key, value in pairs(stuff) do\n\tnew[key] = value\nend"),
			0
		)
	end)

	suite:case("leaves a target that isn't declared as a local", function(assert)
		assert.eq(#lintSource(rule, "for key, value in pairs(stuff) do\n\tglobal[key] = value\nend"), 0)
	end)

	suite:case("leaves a copy whose definition sits outside the loop's block", function(assert)
		assert.eq(
			#lintSource(
				rule,
				"local new = {}\nif cond then\n\tfor key, value in pairs(stuff) do\n\t\tnew[key] = value\n\tend\nend"
			),
			0
		)
	end)

	suite:case("leaves a multi-value assignment", function(assert)
		assert.eq(
			#lintSource(
				rule,
				"local new = {}\nfor key, value in pairs(stuff) do\n\tnew[key], other[key] = value, 1\nend"
			),
			0
		)
	end)

	suite:case("leaves a pairs call followed by another iterable", function(assert)
		assert.eq(
			#lintSource(rule, "local new = {}\nfor key, value in pairs(stuff), what(stuff) do\n\tnew[key] = value\nend"),
			0
		)
	end)

	suite:case("leaves a loop that copies into a parenthesized target", function(assert)
		assert.eq(#lintSource(rule, "local new = {}\nfor key, value in pairs(stuff) do\n\t(new)[key] = value\nend"), 0)
	end)
end)

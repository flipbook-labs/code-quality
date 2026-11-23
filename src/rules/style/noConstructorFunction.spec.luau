local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./noConstructorFunction")

test.suite("no_constructor_function", function(suite)
	suite:case("flags a local function that only returns a table", function(assert)
		local source = table.concat({
			"local function member(name: string)",
			'\treturn { sourceKind = "path", source = `./workspace/{name}` }',
			"end",
			"",
			'return { package = { dependencies = { semver = member("semver") } } }',
		}, "\n")
		local violations = lintSource(rule, source)
		assert.eq(#violations, 1)
		assert.eq(violations[1].location.beginLine, 1)
	end)

	suite:case("flags a function expression assigned to a local", function(assert)
		assert.eq(#lintSource(rule, "local makeOptions = function()\n\treturn {}\nend"), 1)
	end)

	suite:case("leaves a function the module exports alone", function(assert)
		assert.eq(#lintSource(rule, "local function create()\n\treturn {}\nend\n\nreturn create"), 0)
		assert.eq(#lintSource(rule, "local function create()\n\treturn {}\nend\n\nreturn { create = create }"), 0)
		assert.eq(
			#lintSource(rule, "local function create()\n\treturn {}\nend\n\nreturn table.freeze({ create = create })"),
			0
		)
	end)

	suite:case("leaves a function used as a value alone", function(assert)
		local exported = "local function create()\n\treturn {}\nend\n\nlocal M = { new = create }\n\nreturn M"
		assert.eq(#lintSource(rule, exported), 0)
		local callback = "local function create()\n\treturn {}\nend\n\nlocal value = useMemo(create, {})"
		assert.eq(#lintSource(rule, callback), 0)
	end)

	suite:case("leaves a function that does more than return a table alone", function(assert)
		assert.eq(#lintSource(rule, "local function create(x)\n\tlocal y = x * 2\n\treturn { y = y }\nend"), 0)
		assert.eq(#lintSource(rule, "local function create(x)\n\treturn { x = x }, x\nend"), 0)
		assert.eq(#lintSource(rule, "local function create(x)\n\treturn table.freeze({ x = x })\nend"), 0)
	end)

	suite:case("leaves callbacks and table fields alone", function(assert)
		local source = table.concat({
			"local value = useMemo(function()",
			"\treturn {}",
			"end, {})",
			"local M = {}",
			"function M.new()",
			"\treturn {}",
			"end",
			"M.build = function()",
			"\treturn {}",
			"end",
		}, "\n")
		assert.eq(#lintSource(rule, source), 0)
	end)
end)

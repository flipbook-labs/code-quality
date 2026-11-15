local test = require("@std/test")

local migration = require("./stringMethodCall")
local transformSource = require("../lib/transformSource")

test.suite("stringMethodCall code mod", function(suite)
	suite:case("moves the first argument in front of the call", function(assert)
		assert.eq(transformSource(migration, 'local index = string.find(line, "x")'), 'local index = line:find("x")')
	end)

	suite:case("rewrites a call with no other arguments", function(assert)
		assert.eq(transformSource(migration, "local name = string.lower(raw)"), "local name = raw:lower()")
	end)

	suite:case("keeps the remaining arguments as written", function(assert)
		local source = 'local text = string.gsub(\n\tcontent,\n\t"a", -- the old name\n\t"b"\n)'
		local expected = 'local text = content:gsub(\n\t"a", -- the old name\n\t"b"\n)'
		assert.eq(transformSource(migration, source), expected)
	end)

	suite:case("leaves names, indexes, and calls without parentheses", function(assert)
		local source = table.concat({
			"string.split(self.path, '/')",
			"string.split(paths[1], '/')",
			"string.split(getPath(), '/')",
			"local parts = string.split((path), '/')",
		}, "\n")
		local expected = table.concat({
			"self.path:split('/')",
			"paths[1]:split('/')",
			"getPath():split('/')",
			"local parts = (path):split('/')",
		}, "\n")
		assert.eq(transformSource(migration, source), expected)
	end)

	suite:case("wraps other receivers in parentheses", function(assert)
		assert.eq(
			transformSource(migration, 'local index = string.find(a .. b, "x")'),
			'local index = (a .. b):find("x")'
		)
		assert.eq(
			transformSource(migration, "local size = string.len(value :: string)"),
			"local size = (value :: string):len()"
		)
		assert.eq(
			transformSource(migration, "local text = string.upper(if loud then a else b)"),
			"local text = (if loud then a else b):upper()"
		)
	end)

	suite:case("rewrites calls nested inside the receiver", function(assert)
		assert.eq(
			transformSource(migration, "local initial = string.sub(string.upper(name), 1, 1)"),
			"local initial = name:upper():sub(1, 1)"
		)
	end)

	suite:case("rewrites calls nested in the other arguments", function(assert)
		assert.eq(
			transformSource(migration, "local index = string.find(line, string.lower(word))"),
			"local index = line:find(word:lower())"
		)
	end)

	suite:case("leaves calls the rule doesn't flag alone", function(assert)
		local source = table.concat({
			'local divider = string.rep("-", 20)',
			"local letter = string.char(65)",
			"local index = table.find(list, value)",
			'local position = line:find("x")',
		}, "\n")
		assert.eq(transformSource(migration, source), source)
	end)

	suite:case("leaves a literal that isn't a string alone", function(assert)
		local source = "local digits = string.rep(5, 3)\nlocal more = string.rep((5), 3)"
		assert.eq(transformSource(migration, source), source)
	end)

	suite:case("leaves a statement that would start with a parenthesis alone", function(assert)
		local source = table.concat({
			"local saved = getValue()",
			"string.gsub(a .. b, 'x', 'y')",
			"string.gsub((name), 'x', 'y')",
			"string.sub(string.lower(a .. b), 1, 2)",
		}, "\n")
		local expected = table.concat({
			"local saved = getValue()",
			"string.gsub(a .. b, 'x', 'y')",
			"string.gsub((name), 'x', 'y')",
			"string.sub((a .. b):lower(), 1, 2)",
		}, "\n")
		assert.eq(transformSource(migration, source), expected)
	end)

	suite:case("rewrites a statement that starts with a name", function(assert)
		assert.eq(transformSource(migration, "string.gsub(name, 'x', 'y')"), "name:gsub('x', 'y')")
	end)

	suite:case("leaves a call that passes along several values alone", function(assert)
		local source = "local part = string.sub(getRange())\nlocal first = string.byte(...)"
		assert.eq(transformSource(migration, source), source)
	end)

	suite:case("rewrites a call receiver followed by other arguments", function(assert)
		assert.eq(
			transformSource(migration, "local part = string.sub(getText(), 1, 2)"),
			"local part = getText():sub(1, 2)"
		)
	end)

	suite:case("leaves a call with a comment inside its function name alone", function(assert)
		local source = "local part = string --[[note]].sub(text, 1, 2)\nlocal other = string.--[[note]]sub(text, 1, 2)"
		assert.eq(transformSource(migration, source), source)
	end)

	suite:case("keeps comments before and after the call", function(assert)
		assert.eq(
			transformSource(migration, "local part = --[[note]] string.sub(text, 1, 2) -- trailing"),
			"local part = --[[note]] text:sub(1, 2) -- trailing"
		)
	end)

	suite:case("leaves a call with a comment around its first argument alone", function(assert)
		local source = "local part = string.sub(\n\ttext, -- the label\n\t1,\n\t2\n)"
		assert.eq(transformSource(migration, source), source)
	end)
end)

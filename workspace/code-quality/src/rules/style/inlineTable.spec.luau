local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./inlineTable")

test.suite("inline_table", function(suite)
	suite:case("flags four array elements on one line", function(assert)
		assert.eq(#lintSource(rule, 'local t = { "a", "b", "c", "d" }'), 1)
	end)

	suite:case("leaves three array elements on one line alone", function(assert)
		assert.eq(#lintSource(rule, 'local t = { "a", "b", "c" }'), 0)
	end)

	suite:case("flags four keyed fields on one line", function(assert)
		assert.eq(#lintSource(rule, "local t = { a = 1, b = 2, c = 3, d = 4 }"), 1)
	end)

	suite:case("leaves three keyed fields on one line alone", function(assert)
		assert.eq(#lintSource(rule, "local t = { a = 1, b = 2, c = 3 }"), 0)
	end)

	suite:case("counts bracketed keys as entries", function(assert)
		assert.eq(#lintSource(rule, 'local t = { a = 1, ["b"] = 2, [3] = 3, [4] = 4 }'), 1)
	end)

	suite:case("leaves a mixed table with three entries alone", function(assert)
		assert.eq(#lintSource(rule, "local t = { x = 1, 123, [4] = true }"), 0)
	end)

	suite:case("flags a mixed table with four entries", function(assert)
		assert.eq(#lintSource(rule, "local t = { x = 1, 123, [4] = true, 456 }"), 1)
	end)

	suite:case("flags each nested inline table on its own", function(assert)
		assert.eq(#lintSource(rule, "local t = {\n\ta = { 1, 2, 3, 4 },\n\tb = { 5, 6, 7, 8 },\n}"), 2)
	end)

	suite:case("leaves an expanded table alone", function(assert)
		assert.eq(#lintSource(rule, "local t = {\n\ta = 1,\n\tb = 2,\n\tc = 3,\n\td = 4,\n}"), 0)
	end)

	suite:case("leaves an empty table alone", function(assert)
		assert.eq(#lintSource(rule, "local t = {}"), 0)
	end)

	suite:case("flags a returned table with a single keyed field", function(assert)
		assert.eq(#lintSource(rule, "return { ok = true }"), 1)
	end)

	suite:case("flags a returned table with a single array element", function(assert)
		assert.eq(#lintSource(rule, "return { a }"), 1)
	end)

	suite:case("flags a returned table wrapped in a cast or parentheses", function(assert)
		assert.eq(#lintSource(rule, "return { ok = true } :: Result"), 1)
		assert.eq(#lintSource(rule, "return ({ ok = true })"), 1)
	end)

	suite:case("words the message for a returned table separately", function(assert)
		local violations = lintSource(rule, "return { a = a, b = b, c = c, d = d }")
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "returned table")
	end)

	suite:case("leaves a returned empty table alone", function(assert)
		assert.eq(#lintSource(rule, "return {}"), 0)
	end)

	suite:case("leaves an expanded returned table alone", function(assert)
		assert.eq(#lintSource(rule, "return {\n\tok = true,\n}"), 0)
	end)

	suite:case("flags a table type with four fields", function(assert)
		local violations = lintSource(rule, "type Foo = { x: number, y: number, z: number, a: number }")
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "table type")
	end)

	suite:case("leaves a table type with three fields alone", function(assert)
		assert.eq(#lintSource(rule, "type Foo = { x: number, y: number, z: number }"), 0)
	end)

	suite:case("counts an indexer in a table type as one entry", function(assert)
		assert.eq(#lintSource(rule, "type Foo = { x: number, y: number, [string]: number }"), 0)
		assert.eq(#lintSource(rule, "type Foo = { x: number, y: number, z: number, [string]: number }"), 1)
	end)

	suite:case("flags table types in annotations, parameters and return types", function(assert)
		assert.eq(#lintSource(rule, "local t: { a: number, b: number, c: number, d: number } = nil"), 1)
		assert.eq(
			#lintSource(
				rule,
				"local function f(x: { a: number, b: number, c: number, d: number }): { a: number, b: number, c: number, d: number }\n\treturn x\nend"
			),
			2
		)
	end)

	suite:case("flags a nested table type inside an expanded one", function(assert)
		local violations =
			lintSource(rule, "type Foo = {\n\tinner: { a: number, b: number, c: number, [string]: number },\n}")
		assert.eq(#violations, 1)
		-- Lute crashes on a report whose location lies inside a table type
		-- (flipbook-labs/code-quality#14), so the rule reports the outermost
		-- table type instead.
		assert.eq(violations[1].location.beginLine, 1)
		assert.eq(violations[1].location.endLine, 3)
	end)

	suite:case("leaves an expanded table type alone", function(assert)
		assert.eq(#lintSource(rule, "type Foo = {\n\tx: number,\n\ty: number,\n\tz: number,\n\ta: number,\n}"), 0)
	end)

	suite:case("leaves an array type alone", function(assert)
		assert.eq(#lintSource(rule, "type Foo = { number }"), 0)
	end)
end)

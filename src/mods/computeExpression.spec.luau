local test = require("@std/test")

local migration = require("./computeExpression")
local transformSource = require("../lib/transformSource")

local function compute(source: string): string
	return transformSource(migration, source)
end

test.suite("computeExpression code mod", function(suite)
	suite:case("folds arithmetic on literals", function(assert)
		assert.eq(compute("local timeout = 2 * 60 * 1000"), "local timeout = 120000")
		assert.eq(compute("local x = 7 // 2 + 7 % 2 + 2 ^ 3"), "local x = 12")
		assert.eq(compute("local x = 0.1 + 0.2"), "local x = 0.30000000000000004")
		assert.eq(compute("local x = -1000"), "local x = -1000")
		assert.eq(compute("local x = 2 * 60000"), "local x = 120000")
	end)

	suite:case("folds comparisons and logic", function(assert)
		assert.eq(compute('local isDev = "prod" == "development"'), "local isDev = false")
		assert.eq(compute("local x = 1 ~= 2"), "local x = true")
		assert.eq(compute('local x = "a" < "b"'), "local x = true")
		assert.eq(compute("local x = not nil"), "local x = true")
	end)

	suite:case("folds strings", function(assert)
		assert.eq(compute('local x = "a" .. 1 .. "\\n"'), 'local x = "a1\\n"')
		assert.eq(compute("local x = #'abc'"), "local x = 3")
		assert.eq(compute('local x = "10" + 1'), "local x = 11")
		assert.eq(compute("local x = `id {1}` == 'id 1'"), "local x = true")
	end)

	suite:case("folds if expressions with a known condition", function(assert)
		assert.eq(compute("local x = if true then 1 else 2"), "local x = 1")
		assert.eq(compute("local x = if false then 1 elseif true then 2 else 3"), "local x = 2")
	end)

	suite:case("keeps the deciding side of and and or", function(assert)
		assert.eq(compute("local x = true and value"), "local x = value")
		assert.eq(compute("local x = nil or value"), "local x = value")
		assert.eq(compute("local x = false and value"), "local x = false")
		assert.eq(compute("local x = {} or value"), "local x = {}")
	end)

	suite:case("folds the side it keeps", function(assert)
		assert.eq(compute("local x = true and { 1 + 1 }"), "local x = { 2 }")
		assert.eq(compute("local x = true and y + (1 + 1)"), "local x = y + (2)")
	end)

	suite:case("keeps a call to one value with parentheses", function(assert)
		assert.eq(compute("return true and f()"), "return (f())")
		assert.eq(compute("return nil or ..."), "return (...)")
	end)

	suite:case("writes numbers without a literal as divisions", function(assert)
		assert.eq(compute("local x = 1 / 0"), "local x = (1/0)")
		assert.eq(compute("local x = -1 / 0"), "local x = (-1/0)")
		assert.eq(compute("local x = 0 / 0"), "local x = (0/0)")
	end)

	suite:case("keeps a space between minus signs", function(assert)
		assert.eq(compute("local x = a -(1 - 2)"), "local x = a -(-1)")
		assert.eq(compute("local x = a -#'a' * -1"), "local x = a - -1")
	end)

	suite:case("leaves expressions that read names, fields, or calls alone", function(assert)
		local source = table.concat({
			"local a = x + 1",
			"local b = -x",
			"local c = not x",
			"local d = t.field == 1",
			"local e = f() and true",
			"local g = x == x",
		}, "\n")
		assert.eq(compute(source), source)
	end)

	suite:case("leaves values without a literal alone", function(assert)
		local source = "local a = {} == {}\nlocal b = #{}\nlocal c = 'a' + 1"
		assert.eq(compute(source), "local a = false\nlocal b = #{}\nlocal c = 'a' + 1")
	end)

	suite:case("keeps an and whose left side has side effects", function(assert)
		local source = "local x = f() and 1"
		assert.eq(compute(source), source)
	end)
end)

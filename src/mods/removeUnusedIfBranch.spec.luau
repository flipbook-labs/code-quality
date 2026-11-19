local test = require("@std/test")

local migration = require("./removeUnusedIfBranch")
local transformSource = require("../lib/transformSource")

local function simplify(source: string): string
	return transformSource(migration, source)
end

local function lines(list: { string }): string
	return table.concat(list, "\n") .. "\n"
end

test.suite("removeUnusedIfBranch code mod", function(suite)
	suite:case("removes an if that never runs", function(assert)
		assert.eq(simplify(lines({ "a()", "if false then", "\tb()", "end", "c()" })), lines({ "a()", "c()" }))
	end)

	suite:case("moves the block of an if that always runs into the enclosing block", function(assert)
		assert.eq(simplify(lines({ "if true then", "\tprint(1)", "end", "c()" })), lines({ "print(1)", "c()" }))
	end)

	suite:case("keeps the block's locals scoped with do", function(assert)
		local source = lines({ "if true then", "\tlocal x = 1", "\tprint(x)", "end" })
		assert.eq(simplify(source), lines({ "do", "\tlocal x = 1", "\tprint(x)", "end" }))
		local withType = lines({ "if true then", "\ttype T = number", "end" })
		assert.eq(simplify(withType), lines({ "do", "\ttype T = number", "end" }))
	end)

	suite:case("wraps a block that ends in return", function(assert)
		local source = lines({ "local function f()", "\tif true then", "\t\treturn 1", "\tend", "\tprint(2)", "end" })
		local expected = lines({ "local function f()", "\tdo", "\t\treturn 1", "\tend", "\tprint(2)", "end" })
		assert.eq(simplify(source), expected)
	end)

	suite:case("wraps a block when a statement around it opens with (", function(assert)
		local first = lines({ "a()", "if true then", "\t(f or g)()", "end" })
		assert.eq(simplify(first), lines({ "a()", "do", "\t(f or g)()", "end" }))
		local after = lines({ "if true then", "\ta()", "end", "(f or g)()" })
		assert.eq(simplify(after), lines({ "do", "\ta()", "end", "(f or g)()" }))
	end)

	suite:case("runs the else when every branch is removed", function(assert)
		local source = lines({ "if false then", "\ta()", "else", "\tb()", "end" })
		assert.eq(simplify(source), lines({ "b()" }))
	end)

	suite:case("removes branches that never run", function(assert)
		local source = lines({ "if false then", "\ta()", "elseif c then", "\tb()", "elseif nil then", "\td()", "end" })
		assert.eq(simplify(source), lines({ "if c then", "\tb()", "end" }))
	end)

	suite:case("turns a branch that always runs into the else", function(assert)
		local source = lines({
			"if c then",
			"\ta()",
			"elseif true then",
			"\tb()",
			"elseif d then",
			"\te()",
			"else",
			"\tf()",
			"end",
		})
		assert.eq(simplify(source), lines({ "if c then", "\ta()", "else", "\tb()", "end" }))
	end)

	suite:case("removes an empty else", function(assert)
		assert.eq(simplify("if x then a() else end\n"), "if x then a() end\n")
	end)

	suite:case("keeps a condition with side effects", function(assert)
		-- A table constructor is always truthy, but building this one calls
		-- `f`.
		local never = lines({ "if not { f() } then", "\ta()", "else", "\tb()", "end" })
		assert.eq(simplify(never), lines({ "if not { f() } then", "else", "\tb()", "end" }))
		local always = lines({ "if { f() } then", "\ta()", "elseif c then", "\td()", "else", "\tb()", "end" })
		assert.eq(simplify(always), lines({ "if { f() } then", "\ta()", "end" }))
	end)

	suite:case("keeps a branch that declares a local in its condition", function(assert)
		local source = lines({ "if local x = true then", "\tprint(x)", "end" })
		assert.eq(simplify(source), source)
	end)

	suite:case("simplifies ifs inside the block it keeps", function(assert)
		local source = lines({ "if true then", "\tif false then", "\t\ta()", "\tend", "\tb()", "end" })
		assert.eq(simplify(source), lines({ "b()" }))
	end)

	suite:case("leaves an if with conditions it can't evaluate alone", function(assert)
		local source = lines({ "if a then", "\tb()", "elseif c == 1 then", "\td()", "else", "\te()", "end" })
		assert.eq(simplify(source), source)
	end)

	suite:case("keeps a statement that opens with ( apart from the one before", function(assert)
		assert.eq(simplify(lines({ "a()", "if false then b() end", "(f or g)()" })), lines({ "a()", ";(f or g)()" }))
	end)

	suite:case("reduces an if expression to the result that runs", function(assert)
		assert.eq(simplify("local x = if true then a else b"), "local x = a")
		assert.eq(simplify("local x = if false then a elseif nil then b else c"), "local x = c")
	end)

	suite:case("wraps a result that could bind differently or return several values", function(assert)
		assert.eq(simplify("local x = 2 * if false then 0 else 3 + 4"), "local x = 2 * (3 + 4)")
		assert.eq(simplify("return if true then f() else nil"), "return (f())")
	end)

	suite:case("removes branches from an if expression", function(assert)
		assert.eq(simplify("local x = if false then 1 elseif c then 2 else 3"), "local x = if c then 2 else 3")
		assert.eq(simplify("local x = if c then 1 elseif true then 2 else 3"), "local x = if c then 1 else 2")
		assert.eq(simplify("local x = if c then 1 elseif false then 2 else 3"), "local x = if c then 1 else 3")
	end)

	suite:case("keeps conditions with side effects in an if expression", function(assert)
		assert.eq(
			simplify("local x = if { f() } then 1 elseif c then 2 else 3"),
			"local x = if { f() } then 1 else nil"
		)
		assert.eq(simplify("local x = if not { f() } then 1 else 3"), "local x = if not { f() } then nil else 3")
		assert.eq(
			simplify("local x = if c then 1 elseif not { f() } then 2 else 3"),
			"local x = if c then 1 elseif not { f() } then nil else 3"
		)
	end)
end)

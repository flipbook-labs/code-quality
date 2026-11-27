local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./preferBlockComment")

local function fixFor(source: string, options: { [string]: unknown }?): string?
	local violations = lintSource(rule, source, options)
	local fix = if violations[1] then violations[1].suggestedfix else nil
	return if fix then fix.fix else nil
end

test.suite("prefer_block_comment", function(suite)
	suite:case("flags a run of four comment lines", function(assert)
		local source = "-- one\n-- two\n-- three\n-- four\nlocal x = 1"
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("leaves a run of three comment lines alone", function(assert)
		assert.eq(#lintSource(rule, "-- one\n-- two\n-- three\nlocal x = 1"), 0)
	end)

	suite:case("doesn't count bare `--` lines between paragraphs", function(assert)
		local source = "-- one\n-- two\n--\n-- three\nlocal x = 1"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("flags paragraphs that add up to four lines of text", function(assert)
		local source = "-- one\n-- two\n--\n-- three\n-- four\nlocal x = 1"
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("treats a blank line as the end of a run", function(assert)
		local source = "-- one\n-- two\n\n-- three\n-- four\nlocal x = 1"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("treats a directive as the end of a run", function(assert)
		local source = "-- one\n-- two\n-- lute-lint-ignore(no_any)\n-- three\n-- four\nlocal x = 1"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves `---` doc comments alone", function(assert)
		local source = "--- one\n--- two\n--- three\n--- four\nlocal x = 1"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves a comment that follows code on its line out of the run", function(assert)
		local source = "local x = 1 -- one\n-- two\n-- three\n-- four\nlocal y = 2"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("flags runs inside nested blocks", function(assert)
		local source = "if x then\n\t-- one\n\t-- two\n\t-- three\n\t-- four\n\tprint(x)\nend"
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("flags a run before a block's closing `end`", function(assert)
		local source = "do\n\tprint(1)\n\t-- one\n\t-- two\n\t-- three\n\t-- four\nend"
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("reports the run's location", function(assert)
		local violations = lintSource(rule, "local x = 1\n\t-- one\n\t-- two\n\t-- three\n\t-- four\nlocal y = 2")
		local location = violations[1].location
		assert.eq(location.beginLine, 2)
		assert.eq(location.beginColumn, 2)
		assert.eq(location.endLine, 5)
		assert.eq(location.endColumn, 9)
	end)

	suite:case("suggests a block comment indented one level", function(assert)
		local fix = fixFor("-- one\n-- two\n--\n-- three\n-- four\nlocal x = 1")
		assert.eq(fix, "--[[\n\tone\n\ttwo\n\n\tthree\n\tfour\n]]")
	end)

	suite:case("indents the block from the run's own indentation", function(assert)
		local fix = fixFor("do\n\t-- one\n\t-- two\n\t-- three\n\t-- four\n\tprint(1)\nend")
		assert.eq(fix, "--[[\n\t\tone\n\t\ttwo\n\t\tthree\n\t\tfour\n\t]]")
	end)

	suite:case("indents with spaces when the run does", function(assert)
		local fix = fixFor("do\n  -- one\n  -- two\n  -- three\n  -- four\n  print(1)\nend")
		assert.eq(fix, "--[[\n      one\n      two\n      three\n      four\n  ]]")
	end)

	suite:case("keeps indentation past the first space", function(assert)
		local fix = fixFor("-- one:\n--   two\n--   three\n-- four\nlocal x = 1")
		assert.eq(fix, "--[[\n\tone:\n\t  two\n\t  three\n\tfour\n]]")
	end)

	suite:case("adds `=` to the brackets when the text contains `]]`", function(assert)
		local fix = fixFor("-- one\n-- t[a[1]]\n-- three ]=]\n-- four\nlocal x = 1")
		assert.eq(fix, "--[==[\n\tone\n\tt[a[1]]\n\tthree ]=]\n\tfour\n]==]")
	end)

	suite:case("reads the threshold from `line_threshold`", function(assert)
		local source = "-- one\n-- two\nlocal x = 1"
		assert.eq(#lintSource(rule, source, { line_threshold = 2 }), 1)
		assert.eq(#lintSource(rule, source, { line_threshold = 3 }), 0)
	end)

	suite:case("falls back to four for an invalid threshold", function(assert)
		local source = "-- one\n-- two\n-- three\nlocal x = 1"
		assert.eq(#lintSource(rule, source, { line_threshold = 1.5 }), 0)
		assert.eq(#lintSource(rule, source, { line_threshold = "2" }), 0)
	end)

	suite:case("fixes only the run when reporting at a table type", function(assert)
		local source = "type T = {\n\t-- one\n\t-- two\n\t-- three\n\t-- four\n\tfield: string,\n}"
		local violations = lintSource(rule, source)
		assert.eq(violations[1].location.beginLine, 1)
		local fix = violations[1].suggestedfix
		local fixLocation = if fix then fix.location else nil
		assert.eq(if fixLocation then fixLocation.beginLine else nil, 2)
		assert.eq(if fixLocation then fixLocation.endLine else nil, 5)
	end)

	suite:case("leaves block comments alone", function(assert)
		assert.eq(#lintSource(rule, "--[[\n\tone\n\ttwo\n\tthree\n\tfour\n]]\nlocal x = 1"), 0)
	end)
end)

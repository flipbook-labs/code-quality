local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./badStringEscape")

test.suite("bad_string_escape", function(suite)
	suite:case("leaves valid escapes alone", function(assert)
		local source = table.concat({
			[[local x = "\a\b\f\n\r\t\v\"\\"]],
			[[local x = "\97\0\x41\u{1337}"]],
			[[local x = "a\z
				b"]],
			[[local x = "a\
b"]],
		}, "\n")
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("flags an escape that doesn't exist", function(assert)
		local violations = lintSource(rule, [[local bad = "\m"]])
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "`\\m`")
		assert.eq(violations[1].location.beginColumn, 14)
		assert.eq(violations[1].location.endColumn, 16)
	end)

	suite:case("flags a single quote escaped in a double-quoted string", function(assert)
		local violations = lintSource(rule, [[local x = "\'\""]])
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "Single quotes")
	end)

	suite:case("flags a double quote escaped in a single-quoted string", function(assert)
		local violations = lintSource(rule, [[local x = '\"\'']])
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "Double quotes")
	end)

	suite:case("reports an escape after a line continuation on its own line", function(assert)
		local violations = lintSource(rule, 'local x = "a\\\n  \\q"')
		assert.eq(#violations, 1)
		assert.eq(violations[1].location.beginLine, 2)
		assert.eq(violations[1].location.beginColumn, 3)
	end)

	suite:case("doesn't treat an escaped backslash as starting an escape", function(assert)
		assert.eq(#lintSource(rule, [[local x = "\\q"]]), 0)
	end)

	suite:case("leaves long strings and interpolated strings alone", function(assert)
		assert.eq(#lintSource(rule, [==[local good = [[\m\"\']]]==]), 0)
		assert.eq(#lintSource(rule, "local good = `\\'{x}`"), 0)
	end)
end)

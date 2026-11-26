local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./commentLineLength")

-- Builds `prefix` followed by `words` five-letter words with a space between
-- each, so each word after the first adds six columns.
local function commentOf(prefix: string, words: number): string
	return prefix .. string.rep("aaaaa ", words - 1) .. "aaaaa"
end

test.suite("comment_line_length", function(suite)
	suite:case("flags a `--` comment longer than 120 columns", function(assert)
		-- 3 + 20 * 6 - 1 = 122 columns.
		local violations = lintSource(rule, commentOf("-- ", 20) .. "\nlocal x = 1")
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "122 columns")
	end)

	suite:case("allows a comment exactly 120 columns wide", function(assert)
		local comment = "-- " .. string.rep("a", 117)
		assert.eq(#lintSource(rule, comment .. " b\nlocal x = 1"), 1)
		assert.eq(#lintSource(rule, comment .. "\nlocal x = 1"), 0)
	end)

	suite:case("flags each long line of a block comment", function(assert)
		local long = commentOf("\t", 21)
		local source = `--[[\n{long}\n\tshort\n{long}\n]]\nlocal x = 1`
		local violations = lintSource(rule, source)
		assert.eq(#violations, 2)
		assert.eq(violations[1].location.beginLine, 2)
		assert.eq(violations[2].location.beginLine, 4)
	end)

	suite:case("flags a long first line of a block comment", function(assert)
		assert.eq(#lintSource(rule, commentOf("--[[ ", 20) .. " ]]\nlocal x = 1"), 1)
	end)

	suite:case("flags lines of a Moonwave doc comment", function(assert)
		local source = `--[=[\n{commentOf("\t", 21)}\n\n\t@within Story\n]=]\nlocal x = 1`
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("flags `---` comments", function(assert)
		assert.eq(#lintSource(rule, commentOf("--- ", 20) .. "\nlocal x = 1"), 1)
	end)

	suite:case("counts a tab as four columns", function(assert)
		-- Four tabs take 16 columns and the comment takes 106, for 122.
		local comment = string.rep("\t", 4) .. "-- " .. string.rep("a", 101) .. " b"
		local source = `do do do do\n{comment}\nprint(1)\nend end end end`
		assert.eq(#lintSource(rule, source), 1)
		local fourSpaces = string.rep(" ", 4)
		local unindented = comment:gsub("\t", "")
		local spaced = `do\n{fourSpaces}{unindented}\nprint(1)\nend`
		assert.eq(#lintSource(rule, spaced), 0)
	end)

	suite:case("counts code before a trailing comment", function(assert)
		local source = "local x = 1 " .. commentOf("-- ", 18)
		assert.eq(#lintSource(rule, source .. "\nlocal y = 2"), 1)
	end)

	suite:case("doesn't count code after a block comment", function(assert)
		local source = "--[[ short ]] local x = " .. string.rep("1 + ", 30) .. "1"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("counts a multibyte character as one column", function(assert)
		local comment = "-- " .. string.rep("é", 117)
		assert.eq(#lintSource(rule, comment .. "\nlocal x = 1"), 0)
	end)

	suite:case("ignores trailing whitespace", function(assert)
		local comment = "-- " .. string.rep("a", 117) .. "   "
		assert.eq(#lintSource(rule, comment .. "\nlocal x = 1"), 0)
	end)

	suite:case("leaves long code lines alone", function(assert)
		local source = "local x = " .. string.rep("1 + ", 40) .. "1"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves long string literals alone", function(assert)
		local text = string.rep("-- aaaaa ", 20)
		assert.eq(#lintSource(rule, `local x = "{text}"`), 0)
		assert.eq(#lintSource(rule, `local x = [[\n{text}\n]]`), 0)
	end)

	suite:case("leaves a single word too long to fit on any line", function(assert)
		local url = "https://example.com/" .. string.rep("a", 120)
		assert.eq(#lintSource(rule, `-- {url}\nlocal x = 1`), 0)
		assert.eq(#lintSource(rule, `-- See {url}\nlocal x = 1`), 0)
	end)

	suite:case("flags words that follow one too long to fit", function(assert)
		local url = "https://example.com/" .. string.rep("a", 120)
		assert.eq(#lintSource(rule, `-- See {url} for more\nlocal x = 1`), 1)
	end)

	suite:case("flags a long word that fits on a line of its own", function(assert)
		local source = "-- " .. string.rep("a", 100) .. " https://example.com/page\nlocal x = 1"
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("reports the long line's location", function(assert)
		local violations = lintSource(rule, `local x = 1\n\t{commentOf("-- ", 20)}\nlocal y = 2`)
		local location = violations[1].location
		assert.eq(location.beginLine, 2)
		assert.eq(location.beginColumn, 2)
		assert.eq(location.endLine, 2)
		assert.eq(location.endColumn, 124)
	end)

	suite:case("reports a block comment's later lines from their text", function(assert)
		local violations = lintSource(rule, `--[[\n\t{commentOf("", 21)}\n]]\nlocal x = 1`)
		assert.eq(violations[1].location.beginColumn, 2)
	end)

	suite:case("reports at the table type for a comment inside one", function(assert)
		local source = `type T = \{\n\t{commentOf("-- ", 20)}\n\tfield: string,\n}`
		local violations = lintSource(rule, source)
		assert.eq(#violations, 1)
		assert.eq(violations[1].location.beginLine, 1)
	end)

	suite:case("reads the limit from `column_width`", function(assert)
		local source = commentOf("-- ", 14) .. "\nlocal x = 1"
		assert.eq(#lintSource(rule, source, { column_width = 80 }), 1)
		assert.eq(#lintSource(rule, source, { column_width = 100 }), 0)
	end)

	suite:case("reads a tab's width from `indent_width`", function(assert)
		local comment = "\t-- " .. string.rep("a", 112) .. " b"
		local source = `do\n{comment}\nprint(1)\nend`
		assert.eq(#lintSource(rule, source), 1)
		assert.eq(#lintSource(rule, source, { indent_width = 2 }), 0)
	end)

	suite:case("falls back to the defaults for invalid options", function(assert)
		local source = commentOf("-- ", 14) .. "\nlocal x = 1"
		assert.eq(#lintSource(rule, source, { column_width = "80" }), 0)
		assert.eq(#lintSource(rule, source, { column_width = 80.5 }), 0)
		assert.eq(#lintSource(rule, source, { column_width = 0 }), 0)
	end)
end)

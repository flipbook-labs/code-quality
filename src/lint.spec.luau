-- Runs `lint` through the real `lute lint`, on files in a temporary folder.

local fs = require("@std/fs")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local lint = require("./lint")

local root = path.format(path.join(system.tmpdir(), `code-quality-lint-spec-{math.random(1, 1e9)}`))

local function writeFile(relative: string, contents: string): string
	local file = path.join(root, relative)
	fs.createDirectory(path.dirname(file), { makeParents = true })
	fs.writeStringToFile(file, contents)
	return path.format(file)
end

local ESCAPE_RULE =
	path.format(path.join(path.dirname(path.resolve(debug.info(1, "s"))), "rules/lints/badStringEscape.luau"))

test.suite("lint", function(suite)
	suite:afterAll(function()
		fs.removeDirectory(root, { recursive = true })
	end)

	suite:case("returns no findings for a clean file", function(assert)
		local file = writeFile("clean.luau", "local x = 1\nreturn x\n")
		assert.eq(lint({ file }, { rules = ESCAPE_RULE }), 0)
	end)

	suite:case("counts findings without failing when blocking is off", function(assert)
		local file = writeFile("escape.luau", 'return "\\q"\n')
		assert.eq(lint({ file }, { rules = ESCAPE_RULE, blocking = false }), 1)
	end)

	suite:case("fails on findings by default", function(assert)
		local file = writeFile("escape-blocking.luau", 'return "\\q"\n')
		assert.throws(function()
			lint({ file }, { rules = ESCAPE_RULE })
		end)
	end)

	suite:case("fails when a rule throws", function(assert)
		local rule = writeFile("rules/throws.luau", 'return { name = "throws", lint = function() error("boom") end }\n')
		local file = writeFile("any.luau", "return nil\n")
		assert.throws(function()
			lint({ file }, { rules = rule, blocking = false })
		end)
	end)
end)

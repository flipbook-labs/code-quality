local test = require("@std/test")

local lintSource = require("../lib/lintSource")
local rule = require("./redundantPathConversion")

local FS = 'local fs = require("@std/fs")\n'
local PATH = 'local path = require("@std/path")\n'

test.suite("redundant_path_conversion", function(suite)
	suite:case("flags `tostring` around an `@std/fs` path", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.exists(tostring(file))"), 1)
	end)

	suite:case("flags `path.format` around an `@std/fs` path", function(assert)
		assert.eq(#lintSource(rule, FS .. PATH .. "fs.readFileToString(path.format(file))"), 1)
	end)

	suite:case("flags a conversion passed to an `@std/path` function", function(assert)
		assert.eq(#lintSource(rule, PATH .. "local name = path.basename(tostring(file))"), 1)
	end)

	suite:case("flags every argument of `path.join`", function(assert)
		assert.eq(#lintSource(rule, PATH .. "path.join(tostring(root), 'src', path.format(file))"), 2)
	end)

	suite:case("flags both paths of a two-path function", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.copy(tostring(from), tostring(to))"), 2)
	end)

	suite:case("flags a conversion inside parentheses", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.exists((tostring(file)))"), 1)
	end)

	suite:case("follows an aliased require", function(assert)
		local source = 'local filesystem = require("@std/fs")\nlocal pathlib = require("@std/path")\n'
			.. "filesystem.remove(pathlib.format(file))"
		local violations = lintSource(rule, source)
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "`filesystem.remove`")
		assert.strContains(violations[1].message, "`pathlib.format`")
	end)

	suite:case("suggests the bare path as the fix", function(assert)
		local violations = lintSource(rule, FS .. "fs.exists(tostring(root / name))")
		local fix = violations[1].suggestedfix
		assert.eq(if fix then fix.fix else nil, "root / name")
	end)

	suite:case("offers no fix when the last argument wraps a call", function(assert)
		local violations = lintSource(rule, PATH .. "path.join(root, tostring(getParts()))")
		assert.eq(#violations, 1)
		assert.eq(violations[1].suggestedfix, nil)
	end)

	suite:case("offers no fix when the last argument wraps `...`", function(assert)
		local violations = lintSource(rule, FS .. "fs.exists(tostring(...))")
		assert.eq(#violations, 1)
		assert.eq(violations[1].suggestedfix, nil)
	end)

	suite:case("still fixes a wrapped call before the last argument", function(assert)
		local violations = lintSource(rule, FS .. "fs.copy(tostring(getSource()), target)")
		local fix = violations[1].suggestedfix
		assert.eq(if fix then fix.fix else nil, "getSource()")
	end)

	suite:case("leaves a reassigned module local alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs = wrapper\nfs.exists(tostring(file))"), 0)
	end)

	suite:case("leaves a bare path alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.exists(file)"), 0)
	end)

	suite:case("leaves arguments past the paths alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.writeStringToFile(file, tostring(count))"), 0)
	end)

	suite:case("leaves a module named `fs` that isn't `@std/fs` alone", function(assert)
		assert.eq(#lintSource(rule, 'local fs = require("@lute/fs")\nfs.exists(tostring(file))'), 0)
	end)

	suite:case("leaves an unknown function alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.read(tostring(file))"), 0)
	end)

	suite:case("leaves `process.run`'s `cwd` alone", function(assert)
		local source = 'local process = require("@std/process")\nprocess.run({ "ls" }, { cwd = tostring(dir) })'
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves `tostring` around a number literal alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.exists(tostring(123))"), 0)
	end)

	suite:case("leaves `tostring` around a boolean literal alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.exists(tostring(true))"), 0)
	end)

	suite:case("leaves `tostring` around a literal in parentheses alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.exists(tostring((123)))"), 0)
	end)

	suite:case("leaves `tostring` with a base argument alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.exists(tostring(a, b))"), 0)
	end)
end)

local test = require("@std/test")

local lintSource = require("../lib/lintSource")
local rule = require("./redundantPathConversion")

local FS = 'local fs = require("@std/fs")\n'
local PATH = 'local path = require("@std/path")\n'
-- A local that visibly holds a `Path`, for cases that need one.
local FILE = 'local file = path.join(root, "file.txt")\n'

test.suite("redundant_path_conversion", function(suite)
	suite:case("flags `tostring` around a local set from an `@std/path` call", function(assert)
		assert.eq(#lintSource(rule, FS .. PATH .. FILE .. "fs.exists(tostring(file))"), 1)
	end)

	suite:case("flags `tostring` around an `@std/path` call", function(assert)
		assert.eq(#lintSource(rule, FS .. PATH .. "fs.exists(tostring(path.join(root, 'file.txt')))"), 1)
	end)

	suite:case("flags `tostring` around a local annotated `Path`", function(assert)
		assert.eq(#lintSource(rule, FS .. "local file: Path = getFile()\nfs.exists(tostring(file))"), 1)
	end)

	suite:case("flags `tostring` around a parameter annotated `path.Path`", function(assert)
		local source = FS .. PATH .. "local function check(file: path.Path)\n\tfs.exists(tostring(file))\nend"
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("flags `path.format` around any value", function(assert)
		assert.eq(#lintSource(rule, FS .. PATH .. "fs.readFileToString(path.format(file))"), 1)
	end)

	suite:case("flags a conversion passed to an `@std/path` function", function(assert)
		assert.eq(#lintSource(rule, PATH .. FILE .. "local name = path.basename(tostring(file))"), 1)
	end)

	suite:case("flags every argument of `path.join`", function(assert)
		assert.eq(#lintSource(rule, PATH .. FILE .. "path.join(tostring(file), 'src', path.format(other))"), 2)
	end)

	suite:case("flags both paths of a two-path function", function(assert)
		local source = FS .. "local from: Path, to: Path = getFrom(), getTo()\nfs.copy(tostring(from), tostring(to))"
		assert.eq(#lintSource(rule, source), 2)
	end)

	suite:case("flags a conversion inside parentheses", function(assert)
		assert.eq(#lintSource(rule, FS .. PATH .. FILE .. "fs.exists((tostring((file))))"), 1)
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
		local violations = lintSource(rule, FS .. PATH .. FILE .. "fs.exists(tostring(file))")
		local fix = violations[1].suggestedfix
		assert.eq(if fix then fix.fix else nil, "file")
	end)

	suite:case("fixes `tostring` around an `@std/path` call in the last argument", function(assert)
		local violations = lintSource(rule, FS .. PATH .. "fs.exists(tostring(path.join(root, name)))")
		local fix = violations[1].suggestedfix
		assert.eq(if fix then fix.fix else nil, "path.join(root, name)")
	end)

	suite:case("offers no fix when the last argument formats a call", function(assert)
		local violations = lintSource(rule, PATH .. "path.join(root, path.format(getParts()))")
		assert.eq(#violations, 1)
		assert.eq(violations[1].suggestedfix, nil)
	end)

	suite:case("offers no fix when the last argument formats `...`", function(assert)
		local violations = lintSource(rule, FS .. PATH .. "fs.exists(path.format(...))")
		assert.eq(#violations, 1)
		assert.eq(violations[1].suggestedfix, nil)
	end)

	suite:case("still fixes a formatted call before the last argument", function(assert)
		local violations = lintSource(rule, FS .. PATH .. "fs.copy(path.format(getSource()), target)")
		local fix = violations[1].suggestedfix
		assert.eq(if fix then fix.fix else nil, "getSource()")
	end)

	suite:case("leaves `tostring` around a value that isn't visibly a path alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.exists(tostring(file))"), 0)
	end)

	suite:case("leaves `tostring` around a number literal alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.exists(tostring(123))"), 0)
	end)

	suite:case("leaves `tostring` around a boolean literal alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.exists(tostring(true))"), 0)
	end)

	suite:case("leaves `tostring` around an `@std/path` call that returns a string alone", function(assert)
		assert.eq(#lintSource(rule, FS .. PATH .. "fs.exists(tostring(path.basename(file)))"), 0)
	end)

	suite:case("leaves `tostring` around an optional `Path` alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "local file: Path? = getFile()\nfs.exists(tostring(file))"), 0)
	end)

	suite:case("leaves `tostring` around a reassigned path local alone", function(assert)
		local source = FS .. PATH .. FILE .. "file = getName()\nfs.exists(tostring(file))"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves `tostring` around a `Path` from another module alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "local file: other.Path = getFile()\nfs.exists(tostring(file))"), 0)
	end)

	suite:case("leaves a reassigned module local alone", function(assert)
		assert.eq(#lintSource(rule, FS .. PATH .. "fs = wrapper\nfs.exists(path.format(file))"), 0)
	end)

	suite:case("leaves a bare path alone", function(assert)
		assert.eq(#lintSource(rule, FS .. "fs.exists(file)"), 0)
	end)

	suite:case("leaves arguments past the paths alone", function(assert)
		assert.eq(#lintSource(rule, FS .. PATH .. FILE .. "fs.writeStringToFile(file, tostring(file))"), 0)
	end)

	suite:case("leaves a module named `fs` that isn't `@std/fs` alone", function(assert)
		local source = 'local fs = require("@lute/fs")\n' .. PATH .. FILE .. "fs.exists(tostring(file))"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves an unknown function alone", function(assert)
		assert.eq(#lintSource(rule, FS .. PATH .. FILE .. "fs.read(tostring(file))"), 0)
	end)

	suite:case("leaves `process.run`'s `cwd` alone", function(assert)
		local source = 'local process = require("@std/process")\n'
			.. PATH
			.. FILE
			.. 'process.run({ "ls" }, { cwd = tostring(file) })'
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves `tostring` with a base argument alone", function(assert)
		assert.eq(#lintSource(rule, FS .. PATH .. FILE .. "fs.exists(tostring(file, 10))"), 0)
	end)
end)

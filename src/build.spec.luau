-- Runs `transform` and `build` through the real `lute transform`, on files in
-- a temporary folder.

local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local Mod = require("./Mod")
local build = require("./build")
local transform = require("./transform")

local root = path.format(path.join(system.tmpdir(), `code-quality-build-{math.random(1, 1e9)}`))

local function writeFile(relative: string, contents: string)
	local file = path.join(root, relative)
	fs.createDirectory(path.dirname(file), { makeParents = true })
	fs.writeStringToFile(file, contents)
end

local function readFile(relative: string): string
	return fs.readFileToString(path.join(root, relative))
end

local function at(relative: string): string
	return path.format(path.join(root, relative))
end

-- `src` becomes `Packages.Example`, and `dist` holds the build's copy of it.
local SOURCEMAP: json.Value = {
	name = "Packages",
	className = "Folder",
	children = {
		{
			name = "Example",
			filePaths = { "src/init.luau" },
			children = {
				{ name = "Foo", filePaths = { "src/Foo.luau" } },
			},
		},
	},
}

test.suite("transform and build", function(suite)
	suite:beforeAll(function()
		writeFile("sourcemap.json", json.serialize(SOURCEMAP))
		writeFile(".luaurc", "{}")
	end)

	suite:afterAll(function()
		fs.removeDirectory(root, { recursive = true })
	end)

	suite:case("transform runs one mod over the given files", function(assert)
		writeFile("fold/value.luau", "return 2 * 60\n")
		transform(Mod.ComputeExpression, { at("fold/value.luau") })
		assert.eq(readFile("fold/value.luau"), "return 120\n")
	end)

	suite:case("transform passes options to the mod", function(assert)
		writeFile("globals/channel.luau", "return _G.BUILD_CHANNEL\n")
		transform(Mod.InjectGlobalValue, { at("globals/channel.luau") }, {
			globals = '{"BUILD_CHANNEL":"prod"}',
		})
		assert.eq(readFile("globals/channel.luau"), 'return "prod"\n')
	end)

	suite:case("transform errors when the mod fails", function(assert)
		writeFile("broken/init.luau", 'return require("./Missing")\n')
		assert.throws(function()
			transform(Mod.ConvertRequire, { at("broken/init.luau") }, {
				sourcemap = at("sourcemap.json"),
			})
		end)
	end)

	suite:case("build converts requires, injects globals, and removes dead code", function(assert)
		local source = table.concat({
			'local Foo = require("@self/Foo")',
			'if _G.BUILD_CHANNEL == "dev" then',
			'\tprint("dev only")',
			"end",
			"return Foo",
			"",
		}, "\n")
		writeFile("src/init.luau", source)
		writeFile("src/Foo.luau", "return nil\n")
		writeFile("dist/init.luau", source)
		writeFile("dist/Foo.luau", "return nil\n")

		build({
			sourceFolder = at("src"),
			buildFolder = at("dist"),
			sourcemap = at("sourcemap.json"),
			globals = {
				BUILD_CHANNEL = "prod",
			},
		})

		assert.eq(readFile("dist/init.luau"), "local Foo = require(script.Foo)\nreturn Foo\n")
	end)

	suite:case("build skips injectGlobalValue when globals is empty", function(assert)
		writeFile("src/init.luau", "return _G.BUILD_CHANNEL\n")
		writeFile("dist/init.luau", "return _G.BUILD_CHANNEL\n")

		build({
			sourceFolder = at("src"),
			buildFolder = at("dist"),
			sourcemap = at("sourcemap.json"),
			globals = {},
		})

		assert.eq(readFile("dist/init.luau"), "return _G.BUILD_CHANNEL\n")
	end)
end)

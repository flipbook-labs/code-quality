local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local migration = require("./convertRequire")
local transformSource = require("../lib/transformSource")

-- A project laid out the way Rojo would build it: `Packages` holds the
-- package's dependencies, and `src` becomes `Packages.Storyteller`.
-- `Packages._Index` is laid out the way Wally installs a package: `charm-ish`
-- sits beside a link module for its dependency, `Dep`. On disk, `Dep.lua` sits
-- one folder above the package's `src`, so `./Dep` from the package finds no
-- file there.
local root = path.format(path.join(system.tmpdir(), `code-quality-convert-require-{math.random(1, 1e9)}`))
local sourcemapPath = path.format(path.join(root, "sourcemap.json"))

local SOURCEMAP: json.Value = {
	name = "Packages",
	className = "Folder",
	children = {
		{ name = "React", filePaths = { "Packages/React.lua" } },
		{
			name = "_Index",
			children = {
				{
					name = "charm-ish@1.0.0",
					children = {
						{ name = "Dep", filePaths = { "Packages/_Index/charm-ish@1.0.0/Dep.lua" } },
						{
							name = "charm-ish",
							filePaths = { "Packages/_Index/charm-ish@1.0.0/charm-ish/src/init.luau" },
							children = {
								{
									name = "Util",
									filePaths = { "Packages/_Index/charm-ish@1.0.0/charm-ish/src/Util.luau" },
								},
							},
						},
					},
				},
			},
		},
		{
			name = "Storyteller",
			filePaths = { "src/init.luau" },
			children = {
				{ name = "Foo", filePaths = { "src/Foo.luau" } },
				{ name = "my-module", filePaths = { "src/my-module.luau" } },
				{ name = "end", filePaths = { "src/end.luau" } },
				{
					name = "Bar",
					filePaths = { "src/Bar/init.luau" },
					children = {
						{ name = "Baz", filePaths = { "src/Bar/Baz.luau" } },
					},
				},
				{
					name = "Folder",
					children = {
						{ name = "Qux", filePaths = { "src/Folder/Qux.luau" } },
					},
				},
				{
					name = "Nested",
					children = {
						{ name = "User", filePaths = { "src/Nested/User.luau" } },
					},
				},
			},
		},
	},
}

local function writeFile(relative: string, contents: string)
	local file = path.join(root, relative)
	fs.createDirectory(path.dirname(file), { makeParents = true })
	fs.writeStringToFile(file, contents)
end

local function convert(source: string, file: string, options: { [string]: string }?): string
	local resolved: { [string]: string } = { sourcemap = sourcemapPath }
	for name, value in options or {} do
		resolved[name] = value
	end
	return transformSource(migration, source, resolved, path.format(path.join(root, file)))
end

test.suite("convertRequire code mod", function(suite)
	suite:beforeAll(function()
		local luaurc: json.Value = {
			aliases = {
				pkg = "./Packages",
				root = "./src",
				std = "~/.lute/std",
			},
		}
		writeFile("sourcemap.json", json.serialize(SOURCEMAP))
		writeFile(".luaurc", json.serialize(luaurc))
		writeFile("src/Nested/.config.luau", 'return { luau = { aliases = { shared = "../Bar" } } }')
	end)

	suite:afterAll(function()
		fs.removeDirectory(root, { recursive = true })
	end)

	suite:case("resolves relative requires", function(assert)
		assert.eq(convert('local Bar = require("./Bar")', "src/Foo.luau"), "local Bar = require(script.Parent.Bar)")
		assert.eq(
			convert('local Foo = require("../Foo")', "src/Bar/Baz.luau"),
			"local Foo = require(script.Parent.Parent.Foo)"
		)
	end)

	suite:case("resolves aliases from the nearest config", function(assert)
		assert.eq(
			convert('local React = require("@pkg/React")', "src/Foo.luau"),
			"local React = require(script.Parent.Parent.React)"
		)
		assert.eq(
			convert('local Baz = require("@root/Bar/Baz")', "src/Foo.luau"),
			"local Baz = require(script.Parent.Bar.Baz)"
		)
		assert.eq(
			convert('local Baz = require("@shared/Baz")', "src/Nested/User.luau"),
			"local Baz = require(script.Parent.Parent.Bar.Baz)"
		)
		assert.eq(
			convert('local React = require("@pkg/React")', "src/Nested/User.luau"),
			"local React = require(script.Parent.Parent.Parent.React)"
		)
	end)

	suite:case("treats an init file as its folder", function(assert)
		assert.eq(convert('local Foo = require("@self/Foo")', "src/init.luau"), "local Foo = require(script.Foo)")
		assert.eq(convert('local Baz = require("@self/Baz")', "src/Bar/init.luau"), "local Baz = require(script.Baz)")
		assert.eq(
			convert('local Baz = require("./Bar/Baz")', "src/Foo.luau"),
			"local Baz = require(script.Parent.Bar.Baz)"
		)
		assert.eq(
			convert('local Foo = require("./Foo")', "src/Bar/init.luau"),
			"local Foo = require(script.Parent.Foo)"
		)
	end)

	suite:case("finds a folder without an init file through its files", function(assert)
		assert.eq(
			convert('local Qux = require("./Folder/Qux")', "src/Foo.luau"),
			"local Qux = require(script.Parent.Folder.Qux)"
		)
	end)

	suite:case("indexes a name that isn't an identifier with brackets", function(assert)
		assert.eq(
			convert('local m = require("./my-module")', "src/Foo.luau"),
			'local m = require(script.Parent["my-module"])'
		)
	end)

	suite:case("resolves a copied file as the source file it came from", function(assert)
		local options =
			{ sourceFolder = path.format(path.join(root, "src")), buildFolder = path.format(path.join(root, "dist")) }
		assert.eq(
			convert('local Bar = require("./Bar")', "dist/Foo.luau", options),
			"local Bar = require(script.Parent.Bar)"
		)
	end)

	suite:case("indexes a reserved word with brackets", function(assert)
		assert.eq(convert('local e = require("./end")', "src/Foo.luau"), 'local e = require(script.Parent["end"])')
	end)

	suite:case("decodes escapes in the require string", function(assert)
		assert.eq(convert('local b = require("./B\\97r")', "src/Foo.luau"), "local b = require(script.Parent.Bar)")
		assert.eq(
			convert('local fs = require("@st\\100/fs")', "src/Foo.luau", { ignore = "@std/*" }),
			'local fs = require("@st\\100/fs")'
		)
	end)

	suite:case("leaves instance requires and other calls alone", function(assert)
		local source = 'local a = require(script.Parent.Foo)\nlocal b = require(`./Foo`)\nlocal c = load("./Foo")'
		assert.eq(convert(source, "src/Foo.luau"), source)
	end)

	suite:case("leaves a file outside the sourcemap alone when it has no string requires", function(assert)
		local source = "local x = require(script.Parent.Foo)"
		assert.eq(convert(source, "scripts/build.luau"), source)
	end)

	suite:case("stops on a require it can't resolve", function(assert)
		assert.throws(function()
			convert('require("@std/fs")', "src/Foo.luau")
		end)
		assert.throws(function()
			convert('require("./Missing")', "src/Foo.luau")
		end)
		assert.throws(function()
			convert('require("Foo")', "src/Foo.luau")
		end)
		assert.throws(function()
			convert('require("./Foo")', "scripts/build.luau")
		end)
	end)

	suite:case("reads a relative require with no file on disk against the instance tree", function(assert)
		local package = "Packages/_Index/charm-ish@1.0.0/charm-ish/src"
		assert.eq(
			convert('local Dep = require("./Dep")', `{package}/init.luau`),
			"local Dep = require(script.Parent.Dep)"
		)
		assert.eq(
			convert('local Dep = require("../Dep")', `{package}/Util.luau`),
			"local Dep = require(script.Parent.Parent.Dep)"
		)
	end)

	suite:case("only reads ./ and ../ requires against the instance tree", function(assert)
		local package = "Packages/_Index/charm-ish@1.0.0/charm-ish/src"
		assert.throws(function()
			convert('require("@self/Dep")', `{package}/init.luau`)
		end)
		assert.throws(function()
			convert('require("./Missing")', `{package}/init.luau`)
		end)
	end)

	suite:case("doesn't read a require against the instance tree when its file exists", function(assert)
		-- The file is on disk but outside the sourcemap, so the require points
		-- at something Rojo doesn't sync, not at the `Dep` instance.
		writeFile("Packages/_Index/charm-ish@1.0.0/charm-ish/Dep.luau", "return nil")
		assert.throws(function()
			convert('require("./Dep")', "Packages/_Index/charm-ish@1.0.0/charm-ish/src/init.luau")
		end)
		fs.remove(path.join(root, "Packages/_Index/charm-ish@1.0.0/charm-ish/Dep.luau"))
	end)

	suite:case("leaves the requires listed in ignore alone", function(assert)
		local source =
			'local fs = require("@std/fs")\nlocal gen = require("./generated/Icons")\nlocal x = require("./Missing")'
		local options = { ignore = "@std/*, ./generated/*, ./Missing" }
		assert.eq(convert(source, "src/Foo.luau", options), source)

		local mixed = 'local fs = require("@std/fs")\nlocal foo = require("../Foo")'
		assert.eq(
			convert(mixed, "src/Bar/Baz.luau", { ignore = "@std/*" }),
			'local fs = require("@std/fs")\nlocal foo = require(script.Parent.Parent.Foo)'
		)
	end)

	suite:case("matches an ignore entry without * exactly", function(assert)
		assert.throws(function()
			convert('require("@std/fs")', "src/Foo.luau", { ignore = "@std" })
		end)
	end)

	suite:case("asks for both copy folders", function(assert)
		assert.throws(function()
			convert('require("./Bar")', "src/Foo.luau", { sourceFolder = "src" })
		end)
	end)
end)

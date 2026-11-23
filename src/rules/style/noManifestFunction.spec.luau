local parser = require("@std/syntax/parser")
local path = require("@std/path")
local test = require("@std/test")

local rule = require("./noManifestFunction")
local types = require("../../types")

-- Runs the rule over `source` as if it were the file at `filePath`, since the
-- rule only checks manifests.
local function lintFile(filePath: string, source: string): { types.LintViolation }
	return rule.lint(parser.parseBlock(source), path.parse(filePath), {
		globals = {},
		options = {},
	})
end

local HELPER = [[
local function member(name: string)
	return { sourceKind = "path", source = `./workspace/{name}` }
end

return {
	package = {
		dependencies = {
			semver = member("semver"),
		},
	},
}
]]

test.suite("no_manifest_function", function(suite)
	suite:case("flags a local function in pkg.luau", function(assert)
		local violations = lintFile("pkg.luau", HELPER)
		assert.eq(#violations, 1)
		assert.eq(violations[1].location.beginLine, 1)
	end)

	suite:case("flags function expressions and declarations in a nested manifest", function(assert)
		local source = "local build = function() return {} end\nfunction helper() end\nreturn {}"
		assert.eq(#lintFile("workspace/semver/pkg.luau", source), 2)
	end)

	suite:case("flags functions in loom.config.luau", function(assert)
		assert.eq(#lintFile("loom.config.luau", HELPER), 1)
	end)

	suite:case("leaves functions in other files alone", function(assert)
		assert.eq(#lintFile("src/pkg.spec.luau", HELPER), 0)
		assert.eq(#lintFile("src/init.luau", HELPER), 0)
	end)

	suite:case("allows types, requires, and plain data in a manifest", function(assert)
		local source = table.concat({
			'local root = require("../../pkg")',
			"type PathDependency = { sourceKind: string, source: string }",
			'local semver: PathDependency = { sourceKind = "path", source = "./workspace/semver" }',
			"return { version = root.version, package = { dependencies = { semver = semver } } }",
		}, "\n")
		assert.eq(#lintFile("pkg.luau", source), 0)
	end)
end)

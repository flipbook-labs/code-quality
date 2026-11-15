local test = require("@std/test")

local lintSource = require("../lib/lintSource")
local rule = require("./stringUnionEnum")

test.suite("string_union_enum", function(suite)
	suite:case("flags an exported union of three string literals", function(assert)
		assert.eq(#lintSource(rule, 'export type Bump = "major" | "minor" | "patch"'), 1)
	end)

	suite:case("leaves a union of two string literals alone", function(assert)
		assert.eq(#lintSource(rule, 'export type Surface = "agent" | "plugin"'), 0)
	end)

	suite:case("leaves a type that isn't exported alone", function(assert)
		assert.eq(#lintSource(rule, 'type Bump = "major" | "minor" | "patch"'), 0)
	end)

	suite:case("leaves a union alone when a frozen table holds its values", function(assert)
		local source = table.concat({
			'export type Bump = "major" | "minor" | "patch"',
			"local Bump = table.freeze({",
			'	Major = "major" :: "major",',
			'	Minor = "minor",',
			'	Patch = "patch",',
			"})",
		}, "\n")
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("flags a union when the frozen table's values differ", function(assert)
		local source = table.concat({
			'export type Bump = "major" | "minor" | "patch"',
			'local Bump = table.freeze({ Major = "major", Minor = "minor" })',
		}, "\n")
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("flags a union when the matching table isn't frozen", function(assert)
		local source = table.concat({
			'export type Bump = "major" | "minor" | "patch"',
			'local Bump = { Major = "major", Minor = "minor", Patch = "patch" }',
		}, "\n")
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("leaves a union that mixes in other types alone", function(assert)
		assert.eq(#lintSource(rule, 'export type Value = "a" | "b" | number'), 0)
	end)
end)

local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./restrictedModulePaths")

local DEPRECATED = "OldLibrary.Utils.deprecatedFunction"

local OPTIONS = {
	restricted_paths = {
		[DEPRECATED] = "has been deprecated. Use NewLibrary.Utils.modernFunction instead.",
	},
}

-- Selene's own restricted_module_paths fixture, which uses the path above in
-- nine places.
local SELENE_FIXTURE = table.concat({
	"local deprecatedFunction = OldLibrary.Utils.deprecatedFunction",
	"",
	"OldLibrary.Utils.deprecatedFunction()",
	"",
	"fn(OldLibrary.Utils.deprecatedFunction)",
	"",
	"local config = { callback = OldLibrary.Utils.deprecatedFunction }",
	"",
	"function getHandler()",
	"    return OldLibrary.Utils.deprecatedFunction",
	"end",
	"",
	"local nested = { deep = { handler = OldLibrary.Utils.deprecatedFunction } }",
	"",
	"local handler = condition and OldLibrary.Utils.deprecatedFunction or nil",
	"",
	"local required = require(OldLibrary.Utils.deprecatedFunction)",
	"",
	"global = OldLibrary.Utils.deprecatedFunction",
}, "\n")

test.suite("restricted_module_paths", function(suite)
	suite:case("matches Selene's fixture", function(assert)
		assert.eq(#lintSource(rule, SELENE_FIXTURE, OPTIONS), 9)
	end)

	suite:case("flags nothing without restricted_paths", function(assert)
		assert.eq(#lintSource(rule, SELENE_FIXTURE), 0)
		assert.eq(#lintSource(rule, SELENE_FIXTURE, { restricted_paths = {} }), 0)
	end)

	suite:case("flags a call to a restricted path, reporting up to the call", function(assert)
		local call = "OldLibrary.Utils.deprecatedFunction(1, 2)"
		local violations = lintSource(rule, call, OPTIONS)
		assert.eq(#violations, 1)
		assert.eq(violations[1].location.endColumn, #call + 1)
	end)

	suite:case("treats a method call as its name in the path", function(assert)
		local options = { restricted_paths = { ["Audio.play"] = "Use Sound:Play instead." } }
		assert.eq(#lintSource(rule, "Audio:play(sound)", options), 1)
		assert.eq(#lintSource(rule, "Audio.play(sound)", options), 1)
	end)

	suite:case("flags a bare restricted name", function(assert)
		local options = { restricted_paths = { legacy = "Gone." } }
		assert.eq(#lintSource(rule, "local x = legacy", options), 1)
	end)

	suite:case("matches the full path exactly", function(assert)
		assert.eq(#lintSource(rule, "local f = OldLibrary.Utils.deprecatedFunctionExtended", OPTIONS), 0)
		assert.eq(#lintSource(rule, "local f = OldLibrary.Utils.deprecatedFunction.more", OPTIONS), 0)
	end)

	suite:case("leaves assignment targets and function names alone", function(assert)
		local source = table.concat({
			"OldLibrary.Utils.deprecatedFunction = nil",
			"function OldLibrary.Utils.deprecatedFunction() end",
		}, "\n")
		assert.eq(#lintSource(rule, source, OPTIONS), 0)
	end)

	suite:case("checks a path inside an assignment target's brackets", function(assert)
		local source = "tables[OldLibrary.Utils.deprecatedFunction] = 1"
		assert.eq(#lintSource(rule, source, OPTIONS), 1)
	end)

	suite:case("skips entries that aren't string to string", function(assert)
		local options = { restricted_paths = { [DEPRECATED] = 3, [1] = "bad" } }
		assert.eq(#lintSource(rule, SELENE_FIXTURE, options), 0)
	end)
end)

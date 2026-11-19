local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./globalUsage")

test.suite("global_usage", function(suite)
	suite:case("matches Selene's fixture", function(assert)
		local source = table.concat({
			"_G.foo = 1",
			"",
			"do",
			"    -- This triggers another lint, but it shouldn't for this one",
			"    local _G = {}",
			"",
			"    _G.bar = 1",
			"end",
		}, "\n")
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("flags a read of _G", function(assert)
		assert.eq(#lintSource(rule, "local env = _G"), 1)
	end)

	suite:case("flags a call through _G", function(assert)
		assert.eq(#lintSource(rule, "_G.run()"), 1)
	end)

	suite:case("flags a function declared on _G", function(assert)
		assert.eq(#lintSource(rule, "function _G.run() end"), 1)
	end)

	suite:case("flags an assignment to _G itself", function(assert)
		assert.eq(#lintSource(rule, "_G = {}"), 1)
	end)

	suite:case("flags _G inside typeof in a type", function(assert)
		local source = table.concat({
			"type T = typeof(_G.foo)",
			"local value: typeof(_G.bar) = nil",
			"local cast = thing :: typeof(_G.baz)",
			"local function f(x: typeof(_G.qux)) end",
		}, "\n")
		assert.eq(#lintSource(rule, source), 4)
	end)

	suite:case("leaves other globals alone", function(assert)
		assert.eq(#lintSource(rule, "print(shared)\nlocal x = game.Workspace"), 0)
	end)

	suite:case("leaves a local named _G alone", function(assert)
		assert.eq(#lintSource(rule, "local _G = {}\n_G.bar = 1"), 0)
	end)

	suite:case("allows a field matching ignore_pattern", function(assert)
		local source = "_G._foo_ = 1\n_G.bar = 1"
		assert.eq(#lintSource(rule, source, { ignore_pattern = "^_.*_$" }), 1)
	end)

	suite:case("flags _G when no ignore_pattern is set", function(assert)
		assert.eq(#lintSource(rule, "_G._foo_ = 1"), 1)
	end)

	suite:case("does not allow a call through _G even when the field matches", function(assert)
		assert.eq(#lintSource(rule, "_G._foo_()", { ignore_pattern = "^_.*_$" }), 1)
	end)
end)

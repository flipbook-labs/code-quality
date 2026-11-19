local process = require("@std/process")
local test = require("@std/test")

local migration = require("./injectGlobalValue")
local transformSource = require("../lib/transformSource")

local function inject(source: string, options: { [string]: string }): string
	return transformSource(migration, source, options)
end

test.suite("injectGlobalValue code mod", function(suite)
	suite:case("replaces every form of the global with a JSON value", function(assert)
		local source = 'print(_G.CHANNEL, _G["CHANNEL"], CHANNEL)'
		assert.eq(inject(source, { identifier = "CHANNEL", value = '"prod"' }), 'print("prod", "prod", "prod")')
	end)

	suite:case("accepts booleans, numbers, and null", function(assert)
		assert.eq(inject("local x = _G.FLAG", { identifier = "FLAG", value = "true" }), "local x = true")
		assert.eq(inject("local x = _G.LIMIT", { identifier = "LIMIT", value = "12.5" }), "local x = 12.5")
		assert.eq(inject("local x = _G.LIMIT", { identifier = "LIMIT", value = "null" }), "local x = nil")
	end)

	suite:case("uses nil when there's no value", function(assert)
		assert.eq(inject("local x = _G.MISSING", { identifier = "MISSING" }), "local x = nil")
	end)

	suite:case("reads the value from an environment variable as a string", function(assert)
		local name = "CODE_QUALITY_INJECT_SPEC"
		process.env[name] = 'say "hi"\n'
		local result = inject("local x = _G.GREETING", { identifier = "GREETING", env = name })
		process.env[name] = nil
		assert.eq(result, 'local x = "say \\"hi\\"\\n"')
	end)

	suite:case("falls back to the value when the environment variable isn't set", function(assert)
		local options = {
			identifier = "CHANNEL",
			env = "CODE_QUALITY_UNSET_SPEC",
			value = '"dev"',
		}
		assert.eq(inject("local x = _G.CHANNEL", options), 'local x = "dev"')
	end)

	suite:case("leaves assignments and other names alone", function(assert)
		local source = table.concat({
			"_G.CHANNEL = 1",
			"CHANNEL = 2",
			"_G:CHANNEL()",
			"local y = _G.OTHER",
			"local t = { CHANNEL = 1 }",
			"local z = t.CHANNEL",
		}, "\n")
		assert.eq(inject(source, { identifier = "CHANNEL", value = "1" }), source)
	end)

	suite:case("leaves a global hidden by a local alone", function(assert)
		local source = "local _G = {}\nlocal CHANNEL = 1\nprint(_G.CHANNEL, CHANNEL)"
		assert.eq(inject(source, { identifier = "CHANNEL", value = "1" }), source)
	end)

	suite:case("wraps a value used as a prefix", function(assert)
		local options = { identifier = "CHANNEL", value = '"prod"' }
		assert.eq(inject("local x = _G.CHANNEL:upper()", options), 'local x = ("prod"):upper()')
		assert.eq(inject('a()\nCHANNEL:gsub("p", "")', options), 'a()\n;("prod"):gsub("p", "")')
	end)

	suite:case("keeps a space between minus signs", function(assert)
		assert.eq(inject("local x = -LIMIT", { identifier = "LIMIT", value = "-5" }), "local x = - -5")
	end)
end)

local process = require("@std/process")
local test = require("@std/test")

local migration = require("./injectGlobalValue")
local transformSource = require("../lib/transformSource")

local function inject(source: string, globals: string): string
	return transformSource(migration, source, { globals = globals })
end

test.suite("injectGlobalValue code mod", function(suite)
	suite:case("replaces every form of the global with a JSON value", function(assert)
		local source = 'print(_G.CHANNEL, _G["CHANNEL"], CHANNEL)'
		assert.eq(inject(source, '{"CHANNEL":"prod"}'), 'print("prod", "prod", "prod")')
	end)

	suite:case("accepts booleans, numbers, and null", function(assert)
		assert.eq(inject("local x = _G.FLAG", '{"FLAG":true}'), "local x = true")
		assert.eq(inject("local x = _G.LIMIT", '{"LIMIT":12.5}'), "local x = 12.5")
		assert.eq(inject("local x = _G.LIMIT", '{"LIMIT":null}'), "local x = nil")
	end)

	suite:case("sets several globals in one run", function(assert)
		local globals = '{"CHANNEL":"prod","__DEV__":false,"LIMIT":3}'
		assert.eq(
			inject("print(_G.CHANNEL, _G.__DEV__, LIMIT, _G.OTHER)", globals),
			'print("prod", false, 3, _G.OTHER)'
		)
	end)

	suite:case("reads the value from an environment variable as a string", function(assert)
		local name = "CODE_QUALITY_INJECT_SPEC"
		process.env[name] = 'say "hi"\n'
		local result = inject("local x = _G.GREETING", `\{"GREETING":\{"env":"{name}"}}`)
		process.env[name] = nil
		assert.eq(result, 'local x = "say \\"hi\\"\\n"')
	end)

	suite:case("falls back to the value when the environment variable isn't set", function(assert)
		local globals = '{"CHANNEL":{"env":"CODE_QUALITY_UNSET_SPEC","value":"dev"}}'
		assert.eq(inject("local x = _G.CHANNEL", globals), 'local x = "dev"')
	end)

	suite:case("uses nil when the environment variable isn't set and there's no value", function(assert)
		assert.eq(inject("local x = _G.MISSING", '{"MISSING":{"env":"CODE_QUALITY_UNSET_SPEC"}}'), "local x = nil")
	end)

	suite:case("rejects globals that aren't an object of supported values", function(assert)
		assert.throws(function()
			inject("local x = 1", "[]")
		end)
		assert.throws(function()
			inject("local x = 1", "{}")
		end)
		assert.throws(function()
			inject("local x = 1", '{"X":{"value":1}}')
		end)
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
		assert.eq(inject(source, '{"CHANNEL":1}'), source)
	end)

	suite:case("leaves a global hidden by a local alone", function(assert)
		local source = "local _G = {}\nlocal CHANNEL = 1\nprint(_G.CHANNEL, CHANNEL)"
		assert.eq(inject(source, '{"CHANNEL":1}'), source)
	end)

	suite:case("wraps a value used as a prefix", function(assert)
		local globals = '{"CHANNEL":"prod"}'
		assert.eq(inject("local x = _G.CHANNEL:upper()", globals), 'local x = ("prod"):upper()')
		assert.eq(inject('a()\nCHANNEL:gsub("p", "")', globals), 'a()\n;("prod"):gsub("p", "")')
	end)

	suite:case("keeps a space between minus signs", function(assert)
		assert.eq(inject("local x = -LIMIT", '{"LIMIT":-5}'), "local x = - -5")
	end)
end)

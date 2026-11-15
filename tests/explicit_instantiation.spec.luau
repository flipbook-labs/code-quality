local test = require("@std/test")

local lintSource = require("./lib/lintSource")
local rule = require("@repo/src/rules/explicit_instantiation")

test.suite("explicit_instantiation", function(suite)
	suite:case("flags a cast `nil` argument", function(assert)
		assert.eq(#lintSource(rule, "local value, setValue = useState(nil :: string?)"), 1)
	end)

	suite:case("flags a cast empty table argument", function(assert)
		assert.eq(#lintSource(rule, "local items = Charm.signal({} :: { Item })"), 1)
	end)

	suite:case("flags cast boolean, number, and string arguments", function(assert)
		local source = table.concat({
			"useState(false :: boolean?)",
			"useState(0 :: Count)",
			'useState("" :: Name)',
		}, "\n")
		assert.eq(#lintSource(rule, source), 3)
	end)

	suite:case("flags a method call", function(assert)
		assert.eq(#lintSource(rule, "store:create(nil :: Item?)"), 1)
	end)

	suite:case("reports a call once even with several cast arguments", function(assert)
		assert.eq(#lintSource(rule, "pair(nil :: A?, nil :: B?)"), 1)
	end)

	suite:case("offers no fix, since the cast type may not be the type parameter", function(assert)
		local violations = lintSource(rule, "local head = first({} :: { number })")
		assert.eq(#violations, 1)
		assert.eq(violations[1].suggestedfix, nil)
	end)

	suite:case("leaves a cast of a variable alone", function(assert)
		assert.eq(#lintSource(rule, "useState(initial :: string?)"), 0)
	end)

	suite:case("leaves explicit instantiation alone", function(assert)
		assert.eq(#lintSource(rule, "useState<<string?>>(nil)"), 0)
	end)

	suite:case("leaves a cast outside a call alone", function(assert)
		assert.eq(#lintSource(rule, "local value = nil :: string?"), 0)
	end)
end)

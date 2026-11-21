local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./emptyLoop")

local COMMENTED_LOOPS = table.concat({
	"for _ = 1, 10 do",
	"    -- waiting",
	"end",
	"for _ = 1, 10 do",
	"    --[[",
	"    waiting",
	"    ]]",
	"end",
}, "\n")

test.suite("empty_loop", function(suite)
	suite:case("flags each kind of empty loop", function(assert)
		local source = table.concat({
			"for _ = 1, 10 do end",
			"for _ in pairs({}) do end",
			"for _ in {} do end",
			"for _ in a() do end",
			"while true do end",
			"repeat until true",
		}, "\n")
		assert.eq(#lintSource(rule, source), 6)
	end)

	suite:case("flags a loop with only blank lines", function(assert)
		assert.eq(#lintSource(rule, "for _ = 1, 10 do\n\n\n\nend"), 1)
	end)

	suite:case("leaves loops with a body alone", function(assert)
		local source = table.concat({
			"for _ = 1, 10 do print('x') end",
			"for _ in pairs({}) do return 1 end",
			"while true do break end",
			"repeat return until true",
		}, "\n")
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("flags a loop with only a comment by default", function(assert)
		assert.eq(#lintSource(rule, COMMENTED_LOOPS), 2)
	end)

	suite:case("counts comments as a body when comments_count is set", function(assert)
		assert.eq(#lintSource(rule, COMMENTED_LOOPS, { comments_count = true }), 0)
	end)

	suite:case("ignores comments in the loop header when comments_count is set", function(assert)
		local source = table.concat({
			"while --[[ready?]] ready do end",
			"for _ = 1, --[[count]] 10 do end",
			"repeat until --[[done?]] done",
		}, "\n")
		assert.eq(#lintSource(rule, source, { comments_count = true }), 3)
	end)

	suite:case("ignores comments outside the loop when comments_count is set", function(assert)
		local source = "-- before\nwhile true do\nend\n-- after"
		assert.eq(#lintSource(rule, source, { comments_count = true }), 1)
	end)
end)

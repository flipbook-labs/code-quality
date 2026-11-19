local parser = require("@std/syntax/parser")
local test = require("@std/test")

local scopeTracker = require("./scopeTracker")

test.suite("scope tracker", function(suite)
	suite:case("records what a declaration shadows", function(assert)
		local analysis = scopeTracker(parser.parseBlock("local x = 1\ndo local x = 2 end"))
		assert.eq(#analysis.declarations, 2)
		assert.eq(analysis.declarations[1].shadowsLocation, nil)
		local shadows = analysis.declarations[2].shadowsLocation
		assert.eq(shadows and shadows.beginLine, 1)
	end)

	suite:case("ends a block's declarations at its end", function(assert)
		local analysis = scopeTracker(parser.parseBlock("do local x = 1 end\nprint(x)"))
		assert.eq(#analysis.declarations, 1)
		assert.eq(#analysis.globals, 2)
		assert.eq(analysis.globals[2].name, "x")
		assert.eq(analysis.globals[2].resolved, false)
	end)

	suite:case("resolves a read before the assignment that creates the global", function(assert)
		local analysis = scopeTracker(parser.parseBlock("function f() return g end\ng = 1"))
		local reads = 0
		for _, reference in analysis.globals do
			if reference.name == "g" and reference.read then
				reads += 1
				assert.eq(reference.resolved, true)
			end
		end
		assert.eq(reads, 1)
	end)

	suite:case("leaves the assignment itself unresolved", function(assert)
		local analysis = scopeTracker(parser.parseBlock("g = 1"))
		assert.eq(#analysis.globals, 1)
		assert.eq(analysis.globals[1].write, "assign")
		assert.eq(analysis.globals[1].resolved, false)
	end)

	suite:case("keeps the first field read directly from a global", function(assert)
		local analysis = scopeTracker(parser.parseBlock('local v = _G.first.second\nlocal w = _G["key"]'))
		assert.eq(analysis.globals[1].firstIndex, "first")
		assert.eq(analysis.globals[2].firstIndex, "key")
	end)

	suite:case("drops the field read when the access is called", function(assert)
		local analysis = scopeTracker(parser.parseBlock("_G.run()"))
		assert.eq(analysis.globals[1].firstIndex, nil)
	end)

	suite:case("treats a function's parameters as declarations in its body", function(assert)
		local analysis = scopeTracker(parser.parseBlock("local function f(a, b) return a end"))
		assert.eq(#analysis.declarations, 3)
	end)
end)

local test = require("@std/test")

local lintSource = require("../../lib/lintSource")
local rule = require("./deprecated")

test.suite("deprecated", function(suite)
	suite:case("flags a deprecated function call", function(assert)
		assert.eq(#lintSource(rule, "local count = table.getn(list)"), 1)
	end)

	suite:case("suggests the replacement with the call's arguments", function(assert)
		local violations = lintSource(rule, "local count = table.getn(list)")
		assert.strContains(violations[1].message, "Try `#list`.")
	end)

	suite:case("leaves out the suggestion when the call has no argument for it", function(assert)
		local violations = lintSource(rule, "local count = table.getn()")
		assert.eq(#violations, 1)
		assert.strNotContains(violations[1].message, "Try")
	end)

	suite:case("flags a deprecated function used as a statement", function(assert)
		assert.eq(#lintSource(rule, "table.foreach(list, print)"), 1)
		assert.eq(#lintSource(rule, "table.foreachi(list, print)"), 1)
	end)

	suite:case("flags a deprecated function nested inside another call", function(assert)
		assert.eq(#lintSource(rule, "print(table.getn(list))"), 1)
	end)

	suite:case("flags a deprecated field read without a call", function(assert)
		local violations = lintSource(rule, "local getCount = table.getn")
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "expression `table.getn`")
	end)

	suite:case("flags a deprecated parameter by its position", function(assert)
		assert.eq(#lintSource(rule, 'local instance = Instance.new("Folder", parent)'), 1)
	end)

	suite:case("reports a call with type arguments once", function(assert)
		assert.eq(#lintSource(rule, "table.foreach<<number>>(items, visit)"), 1)
	end)

	suite:case("wraps an argument built from operators in its replacement", function(assert)
		local violations = lintSource(rule, "local count = table.getn(a or b)")
		assert.strContains(violations[1].message, "`#(a or b)`")
	end)

	suite:case("leaves out a deprecated parameter that is missing or nil", function(assert)
		assert.eq(#lintSource(rule, 'local instance = Instance.new("Folder")'), 0)
		assert.eq(#lintSource(rule, 'local instance = Instance.new("Folder", nil)'), 0)
		assert.eq(#lintSource(rule, 'local instance = Instance.new("Folder", (nil))'), 0)
	end)

	suite:case("flags a deprecated parameter given as the string nil", function(assert)
		assert.eq(#lintSource(rule, 'local instance = Instance.new("Folder", "nil")'), 1)
	end)

	suite:case("leaves other library functions alone", function(assert)
		assert.eq(#lintSource(rule, "table.insert(list, value)"), 0)
		assert.eq(#lintSource(rule, "local folder = Instance.new(className)"), 0)
	end)

	suite:case("leaves a local that shares a deprecated name alone", function(assert)
		local source = table.concat({
			"local table = {}",
			"local count = table.getn(list)",
		}, "\n")
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves method calls on values alone", function(assert)
		assert.eq(#lintSource(rule, "value:getn()"), 0)
	end)

	suite:case("leaves assignments to a deprecated field alone, as Selene does", function(assert)
		assert.eq(#lintSource(rule, "table.getn = nil"), 0)
	end)

	suite:case("flags a deprecated method called on a Roblox global", function(assert)
		local violations = lintSource(rule, "local result = workspace:FindPartOnRay(ray)")
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "Roblox function `workspace:FindPartOnRay` is deprecated")
		assert.strContains(violations[1].message, "WorldRoot:Raycast()")
	end)

	suite:case("flags a deprecated member a Roblox global inherits", function(assert)
		assert.eq(#lintSource(rule, "local copy = script:clone()"), 1)
		assert.eq(#lintSource(rule, "local lighting = game:service(name)"), 1)
		assert.eq(#lintSource(rule, "local userId = plugin:GetStudioUserId()"), 1)
	end)

	suite:case("flags a deprecated property read from a Roblox global", function(assert)
		local violations = lintSource(rule, "local world = game.workspace")
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "Roblox expression `game.workspace`")
	end)

	suite:case("leaves current members of Roblox globals alone", function(assert)
		assert.eq(#lintSource(rule, "local result = workspace:Raycast(origin, direction)"), 0)
		assert.eq(#lintSource(rule, 'local players = game:GetService("Players")'), 0)
		assert.eq(#lintSource(rule, "local world = game.Workspace"), 0)
	end)

	suite:case("leaves deprecated names on other values alone", function(assert)
		assert.eq(#lintSource(rule, "local copy = part:clone()"), 0)
		assert.eq(#lintSource(rule, "local result = workspace.Terrain:clone()"), 0)
	end)

	suite:case("leaves a local named after a Roblox global alone", function(assert)
		local source = table.concat({
			"local workspace = {}",
			"local result = workspace:FindPartOnRay(ray)",
		}, "\n")
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("flags an enum item's legacy name and suggests the current one", function(assert)
		local violations = lintSource(rule, "local axis = Enum.Axis.Left")
		assert.eq(#violations, 1)
		assert.strContains(violations[1].message, "Try `Enum.Axis.X`.")
	end)

	suite:case("flags a deprecated enum item", function(assert)
		assert.eq(#lintSource(rule, "local order = Enum.SortOrder.Custom"), 1)
	end)

	suite:case("flags a deprecated enum once, including its items", function(assert)
		assert.eq(#lintSource(rule, "local status = Enum.Status"), 1)
		assert.eq(#lintSource(rule, "local status = Enum.Status.Poison"), 1)
	end)

	suite:case("leaves current enum items alone", function(assert)
		assert.eq(#lintSource(rule, "local order = Enum.SortOrder.LayoutOrder"), 0)
		assert.eq(#lintSource(rule, "local axis = Enum.Axis.X"), 0)
	end)

	suite:case("allows a Roblox path named in the allow option", function(assert)
		local source = table.concat({
			"local result = workspace:FindPartOnRay(ray)",
			"local axis = Enum.Axis.Left",
		}, "\n")
		assert.eq(#lintSource(rule, source, { allow = { "workspace", "Enum.Axis.*" } }), 0)
	end)

	suite:case("allows a path named in the allow option", function(assert)
		assert.eq(#lintSource(rule, "table.getn(list)", { allow = { "table.getn" } }), 0)
	end)

	suite:case("allows a wildcard in the allow option", function(assert)
		local source = table.concat({
			"table.getn(list)",
			"table.foreach(list, print)",
		}, "\n")
		assert.eq(#lintSource(rule, source, { allow = { "table.*" } }), 0)
	end)

	suite:case("allows everything under a path named in the allow option", function(assert)
		assert.eq(#lintSource(rule, "table.getn(list)", { allow = { "table" } }), 0)
	end)

	suite:case("ignores allow entries that aren't strings", function(assert)
		assert.eq(#lintSource(rule, "table.getn(list)", { allow = { 1, true } }), 1)
	end)

	suite:case("ignores an allow option that isn't a list", function(assert)
		assert.eq(#lintSource(rule, "table.getn(list)", { allow = "table.getn" }), 1)
	end)
end)

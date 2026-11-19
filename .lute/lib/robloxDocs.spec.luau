local test = require("@std/test")

local robloxDocs = require("./robloxDocs")

-- Trimmed copies of the layout creator-docs uses for its generated pages.
local CLASS_PAGE = table.concat({
	"name: WorldRoot",
	"type: class",
	"deprecation_message: ''",
	"methods:",
	"  - name: WorldRoot:FindPartOnRay",
	"    summary: |",
	"      Returns the first part the ray hits.",
	"    tags:",
	"      - Deprecated",
	"    deprecation_message: |",
	"      This function has been deprecated. Use `Class.WorldRoot:Raycast()` along",
	"      with `Datatype.RaycastParams` for new work.",
	"",
	"      Background that doesn't belong in a lint message.",
	"    security: None",
	"  - name: WorldRoot:Raycast",
	"    tags: []",
	"    deprecation_message: ''",
	"properties:",
	"  - name: WorldRoot.Gravity",
	"    deprecation_message: This property is deprecated.",
	"  - name: WorldRoot.Old",
	"    deprecation_message: 'Use `Class.ServiceProvider:GetService()|GetService()` instead.'",
}, "\n")

local ENUM_PAGE = table.concat({
	"name: Status",
	"type: enum",
	"deprecation_message: |",
	"  This enum is deprecated. See [the guide](https://example.com/guide).",
	"items:",
	"  - name: Poison",
	"    value: 0",
	"    deprecation_message: ''",
	"  - name: Confusion",
	"    value: 1",
	"    deprecation_message: >-",
	"      Don't use",
	"      `Enum.Status.Confusion`.",
}, "\n")

test.suite("robloxDocs", function(suite)
	suite:case("reads a member's block message, up to the first blank line", function(assert)
		local messages = robloxDocs.parse(CLASS_PAGE)
		assert.eq(
			messages.items.FindPartOnRay,
			"This function has been deprecated. Use `WorldRoot:Raycast()` along with `RaycastParams` for new work."
		)
	end)

	suite:case("reads an inline message, quoted or not", function(assert)
		local messages = robloxDocs.parse(CLASS_PAGE)
		assert.eq(messages.items.Gravity, "This property is deprecated.")
		assert.eq(messages.items.Old, "Use `GetService()` instead.")
	end)

	suite:case("leaves out a member whose message is empty", function(assert)
		local messages = robloxDocs.parse(CLASS_PAGE)
		assert.eq(messages.items.Raycast, nil)
	end)

	suite:case("leaves the page message out when it's empty", function(assert)
		assert.eq(robloxDocs.parse(CLASS_PAGE).page, nil)
	end)

	suite:case("reads the page's own message and an enum item's", function(assert)
		local messages = robloxDocs.parse(ENUM_PAGE)
		assert.eq(messages.page, "This enum is deprecated. See the guide.")
		assert.eq(messages.items.Confusion, "Don't use `Enum.Status.Confusion`.")
		assert.eq(messages.items.Poison, nil)
	end)

	suite:case("keeps a block from running into the next entry", function(assert)
		local messages = robloxDocs.parse(CLASS_PAGE)
		assert.strNotContains(messages.items.FindPartOnRay, "security")
	end)

	suite:case("finds nothing in a page without messages", function(assert)
		local messages = robloxDocs.parse("name: Part\ntype: class\n")
		assert.eq(messages.page, nil)
		assert.eq(next(messages.items), nil)
	end)

	suite:case("strips reference prefixes", function(assert)
		assert.eq(robloxDocs.cleanMarkup("`Class.Instance:Clone()`"), "`Instance:Clone()`")
		assert.eq(robloxDocs.cleanMarkup("`Library.math.floor()`"), "`math.floor()`")
		assert.eq(robloxDocs.cleanMarkup("`Global.RobloxGlobals.wait()`"), "`wait()`")
	end)
end)

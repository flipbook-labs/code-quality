-- The Roblox APIs the `deprecated` rule can recognize from syntax alone: members
-- read straight off the `game`, `plugin`, `script`, and `workspace` globals,
-- and `Enum` paths. The data comes from src/generated/robloxApiData.luau,
-- which `lute run generate-roblox-api` regenerates from Roblox's API dump.
--
-- Members of any other value, such as `part:clone()`, aren't covered, because
-- a rule that reads syntax can't tell what class the value is.

local robloxApiData = require("../generated/robloxApiData")
local standardLibrary = require("./standardLibrary")

type Entry = robloxApiData.Entry

local function toDeprecation(path: string, entry: Entry?): standardLibrary.Deprecation?
	if entry == nil then
		return nil
	end
	return {
		path = path,
		message = entry.message,
		replace = entry.replace,
	}
end

local robloxApi = {}

-- Looks up a dotted path such as `workspace.FindPartOnRay`,
-- `Enum.Status`, or `Enum.Axis.Left`. A method call is looked up with a dot
-- in place of its colon.
function robloxApi.getDeprecation(path: string): standardLibrary.Deprecation?
	local words = path:split(".")
	local root = words[1]
	if root == "Enum" then
		if #words == 2 then
			return toDeprecation(path, robloxApiData.enums[words[2]])
		elseif #words == 3 then
			return toDeprecation(path, robloxApiData.enumItems[`{words[2]}.{words[3]}`])
		end
		return nil
	end

	local members = robloxApiData.globals[root]
	if members and #words == 2 then
		return toDeprecation(path, members[words[2]])
	end
	return nil
end

return table.freeze(robloxApi)

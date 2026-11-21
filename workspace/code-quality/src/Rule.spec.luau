local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local Rule = require("./Rule")

test.suite("Rule", function(suite)
	suite:case("names every rule in src/rules, and nothing else", function(assert)
		local rulesFolder = path.join(path.dirname(path.resolve(debug.info(1, "s"))), "rules")
		local onDisk: { string } = {}
		for _, folder in { "lints", "style" } do
			for _, entry in fs.listDirectory(path.join(rulesFolder, folder)) do
				if entry.name:match("%.luau$") and not entry.name:match("%.spec%.luau$") then
					local source = fs.readFileToString(path.join(rulesFolder, folder, entry.name))
					local name = source:match('NAME = "([%w_]+)"') or source:match('name = "([%w_]+)"')
					assert.neq(name, nil)
					table.insert(onDisk, name :: string)
				end
			end
		end

		local named: { string } = {}
		for _, value in Rule :: { [string]: string } do
			table.insert(named, value)
		end

		table.sort(onDisk)
		table.sort(named)
		assert.eq(table.concat(named, ","), table.concat(onDisk, ","))
	end)
end)

local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local Mod = require("./Mod")

test.suite("Mod", function(suite)
	suite:case("names every mod in src/mods, and nothing else", function(assert)
		local modsFolder = path.join(path.dirname(path.resolve(debug.info(1, "s"))), "mods")
		local onDisk: { string } = {}
		for _, entry in fs.listDirectory(modsFolder) do
			local name = entry.name:match("^(.+)%.luau$")
			if name and not name:match("%.spec$") then
				table.insert(onDisk, name)
			end
		end

		local named: { string } = {}
		for _, value in Mod :: { [string]: string } do
			table.insert(named, value)
		end

		table.sort(onDisk)
		table.sort(named)
		assert.eq(table.concat(named, ","), table.concat(onDisk, ","))
	end)
end)

-- Checks formatting with StyLua and lints with Selene.

local process = require("@std/process")

local function run(command: { string })
	local result = process.run(command, {
		stdio = "inherit",
	})
	if not result.ok then
		process.exit(result.exitcode)
	end
end

run({ "stylua", "--check", ".lute" })
run({ "selene", ".lute" })

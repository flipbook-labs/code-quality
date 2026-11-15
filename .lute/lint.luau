-- Checks formatting with StyLua and lints with Selene, then runs this
-- package's own rules over itself.

local process = require("@std/process")

local function run(command: { string })
	local result = process.run(command, {
		stdio = "inherit",
	})
	if not result.ok then
		process.exit(result.exitcode)
	end
end

run({ "stylua", "--check", ".lute", "src" })
run({ "selene", ".lute", "src" })
run({ "lute", "lint", "--rules", "src/rules", ".lute", "src" })

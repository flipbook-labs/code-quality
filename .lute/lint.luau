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
-- Lute's parallel linting can crash at random, which fails lint for no reason,
-- so files are linted one at a time: https://github.com/luau-lang/lute/blob/v1.0.1-nightly.20260909/lute/runtime/src/runtime.cpp#L113-L117
run({ "lute", "lint", "--sequential", "--rules", "src/rules", ".lute", "src" })

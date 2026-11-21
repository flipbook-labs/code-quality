-- Checks formatting with StyLua and lints with Selene, then runs this
-- package's own rules over itself through its `lint` function.

local process = require("@std/process")

local CodeQuality = require("@repo/workspace/code-quality/src")

local function run(command: { string })
	local result = process.run(command, {
		stdio = "inherit",
	})
	if not result.ok then
		process.exit(result.exitcode)
	end
end

run({
	"stylua",
	"--check",
	".lute",
	"workspace",
})
run({ "selene", ".lute", "workspace" })
CodeQuality.lint({ ".lute", "workspace" })

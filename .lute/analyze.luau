--[[
	Type-checks the repo's Luau with luau-lsp, in the strict mode set by
	.luaurc. Run `lute setup` once first so the Lute typedefs exist locally. The
	typedefs use read-only properties, which only the new type solver
	understands, so analysis turns it on.
]]

local process = require("@std/process")

local result = process.run({
	"luau-lsp",
	"analyze",
	"--platform=standard",
	"--flag:LuauSolverV2=true",
	"--settings=.vscode/settings.json",
	".lute",
	"workspace",
}, {
	stdio = "inherit",
})

if not result.ok then
	process.exit(result.exitcode)
end

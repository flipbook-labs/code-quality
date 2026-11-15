local path = require("@std/path")
local syntax = require("@std/syntax")

local ignorePattern = require("../../lib/ignorePattern")
local scopeTracker = require("../../lib/scopeTracker")
local types = require("../../types")

local NAME = "shadowing"

local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: types.RuleContext
): { types.LintViolation }
	local pattern = ignorePattern.read(context.options, "ignore_pattern", "^_")
	local violations: { types.LintViolation } = {}

	for _, declaration in scopeTracker(cst).declarations do
		if declaration.shadowsLocation and not ignorePattern.isIgnored(pattern, declaration.name) then
			local violation: types.LintViolation = {
				lintname = NAME,
				location = declaration.location,
				message = "This shadows `"
					.. declaration.name
					.. "`, which is already declared in scope. Rename one of them, or add the name to `ignore_pattern`.",
				severity = "warning",
				sourcepath = sourcepath,
			}
			table.insert(violations, violation)
		end
	end

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

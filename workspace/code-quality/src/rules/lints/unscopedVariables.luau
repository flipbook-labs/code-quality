local path = require("@std/path")
local syntax = require("@std/syntax")

local getReportLocation = require("../../lib/getReportLocation")
local ignorePattern = require("../../lib/ignorePattern")
local scopeTracker = require("../../lib/scopeTracker")
local types = require("../../types")

local NAME = "unscoped_variables"

--[[
	Assigning to a name no local declares creates a global. Selene reports an
	assignment only when no local or earlier assignment has made the name
	visible. The first such assignment makes the name visible for the rest of
	its scope, so later ones in that scope aren't reported.

	Selene also skips assignments to standard-library globals that have fields,
	such as `string = ...`. Lute's rules don't have the standard library, so
	that exception isn't made here.
]]
local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: types.RuleContext
): { types.LintViolation }
	local pattern = ignorePattern.read(context.options, "ignore_pattern", "^_")
	local violations: { types.LintViolation } = {}

	for _, reference in scopeTracker(cst).globals do
		if
			reference.write == "assign"
			and not reference.resolved
			and not ignorePattern.isIgnored(pattern, reference.name)
		then
			local violation: types.LintViolation = {
				lintname = NAME,
				location = getReportLocation(cst, reference.location),
				message = "`" .. reference.name .. "` is not declared locally, and will be available in every scope.",
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

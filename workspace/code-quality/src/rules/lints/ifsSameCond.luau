local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local exprHasSideEffects = require("../../lib/exprHasSideEffects")
local getReportLocation = require("../../lib/getReportLocation")
local similarNodes = require("../../lib/similarNodes")
local types = require("../../types")

local NAME = "ifs_same_cond"

-- Flags an `elseif` whose condition repeats an earlier condition of the same
-- `if`, as Selene does. Conditions with side effects are left alone, since
-- running them twice may do something different.
local function lintIf(stat: syntax.CstStatIf, sourcepath: path.Path?, cst: syntax.CstStatBlock): { types.LintViolation }
	local violations: { types.LintViolation } = {}
	if #stat.elseifs == 0 then
		return violations
	end

	local kept: { syntax.CstExpr } = {}
	if not exprHasSideEffects(stat.condition) then
		table.insert(kept, stat.condition)
	end

	for _, branch in stat.elseifs do
		local condition = branch.condition
		if exprHasSideEffects(condition) then
			continue
		end

		local match: syntax.CstExpr? = nil
		for _, other in kept do
			if similarNodes(other, condition) then
				match = other
				break
			end
		end

		if match then
			local violation: types.LintViolation = {
				lintname = NAME,
				location = getReportLocation(cst, condition.location),
				message = `This \`elseif\` has the same condition as the one on line {match.location.beginLine}.`,
				severity = "warning",
				sourcepath = sourcepath,
			}
			table.insert(violations, violation)
		else
			table.insert(kept, condition)
		end
	end

	return violations
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}
	for _, stat in query.findAllFromRoot(cst, utils.isStatIf).nodes do
		for _, violation in lintIf(stat, sourcepath, cst) do
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

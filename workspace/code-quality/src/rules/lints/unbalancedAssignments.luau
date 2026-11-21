local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")
local unwrapGroups = require("../../lib/unwrapGroups")

local NAME = "unbalanced_assignments"

local function isCall(expr: syntax.CstExpr): boolean
	return utils.isExprCall(unwrapGroups(expr)) ~= nil
end

-- A trailing value that can stand for several, or that reads as setting the
-- rest to nil on purpose, keeps a short right side from being flagged.
--
-- Selene treats `(f())` as a call here even though the parentheses keep only
-- its first value, and it treats `(nil)` as not nil. Both are matched so this
-- flags the same code Selene does.
local function canFillRemainingNames(expr: syntax.CstExpr): boolean
	if utils.isExprGroup(expr) then
		return isCall(expr)
	end
	return utils.isExprVarargs(expr) ~= nil or utils.isExprCall(expr) ~= nil or utils.isExprConstantNil(expr) ~= nil
end

local function spanBetween(first: syntax.Span, last: syntax.Span): syntax.Span
	return syntax.span.create({
		beginLine = first.beginLine,
		beginColumn = first.beginColumn,
		endLine = last.endLine,
		endColumn = last.endColumn,
	})
end

local function lintAssignment(
	cst: syntax.CstStatBlock,
	nameCount: number,
	values: syntax.CstPunctuated<syntax.CstExpr>,
	sourcepath: path.Path?
): types.LintViolation?
	local valueCount = #values
	if valueCount == 0 then
		return nil
	end

	local lastValue = values[valueCount]

	if valueCount > nameCount then
		return {
			lintname = NAME,
			location = getReportLocation(cst, spanBetween(values[nameCount + 1].location, lastValue.location)),
			message = "There are more values on the right side of this assignment than names on the left, so the extras are thrown away.",
			severity = "warning",
			sourcepath = sourcepath,
		}
	end

	if valueCount < nameCount and not canFillRemainingNames(lastValue) then
		local message =
			"There are fewer values on the right side of this assignment than names on the left, so the rest are set to nil."
		for _, value in values do
			if isCall(value) then
				message ..= " A call that isn't last only gives its first return value."
				break
			end
		end

		return {
			lintname = NAME,
			location = getReportLocation(cst, spanBetween(values[1].location, lastValue.location)),
			message = message,
			severity = "warning",
			sourcepath = sourcepath,
		}
	end

	return nil
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}

	local function check(violation: types.LintViolation?)
		if violation then
			table.insert(violations, violation)
		end
	end

	query.findAllFromRoot(cst, utils.isStatAssign):forEach(function(assign)
		check(lintAssignment(cst, #assign.variables, assign.values, sourcepath))
	end)

	query.findAllFromRoot(cst, utils.isStatLocal):forEach(function(declaration)
		check(lintAssignment(cst, #declaration.variables, declaration.values, sourcepath))
	end)

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

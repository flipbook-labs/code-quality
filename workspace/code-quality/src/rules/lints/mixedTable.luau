local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

local NAME = "mixed_table"

--[[
	Flags a table constructor that has both positional entries, like `{ "a" }`,
	and keyed entries, like `{ a = 1 }` or `{ [1] = "a" }`. Like Selene, an
	explicit numeric key counts as keyed, so `{ 1, [2] = b }` is flagged too.
	Each table is reported once, at its first switch between the two kinds.
]]
local function findMixedEntries(tableExpr: syntax.CstExprTable): syntax.Span?
	local lastKeyed: syntax.CstTableExprItem? = nil
	local lastPositional: syntax.CstTableExprItem? = nil

	for _, entry in tableExpr.entries do
		local isPositional = entry.kind == "list"
		local opposite = if isPositional then lastKeyed else lastPositional
		if opposite then
			return syntax.span.create({
				beginLine = opposite.location.beginLine,
				beginColumn = opposite.location.beginColumn,
				endLine = entry.location.endLine,
				endColumn = entry.location.endColumn,
			})
		end

		if isPositional then
			lastPositional = entry
		else
			lastKeyed = entry
		end
	end

	return nil
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	return query.findAllFromRoot(cst, utils.isExprTable):mapToArray(function(tableExpr): types.LintViolation?
		local location = findMixedEntries(tableExpr)
		if not location then
			return nil
		end

		return {
			lintname = NAME,
			location = getReportLocation(cst, location),
			message = "This table mixes positional and keyed entries, which makes iteration and encoding confusing. Make it either an array or a dictionary.",
			severity = "warning",
			sourcepath = sourcepath,
		}
	end)
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

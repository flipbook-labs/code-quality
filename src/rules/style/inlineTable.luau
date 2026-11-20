local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

local NAME = "inline_table"

-- Up to three entries still read well on one line. From four on, each entry
-- gets its own line so the table is easy to scan and diffs stay small. Every
-- kind of entry counts as one: in a table constructor, an array element, a
-- `name = value` field or a `[key] = value` field, and in a table type, a
-- property or an indexer such as `[string]: number`.
local MAX_INLINE_ENTRIES = 3

-- A table that a function returns is that function's result, so it's expanded
-- even with a single entry. An empty `return {}` has nothing to expand.
local MAX_INLINE_RETURNED_ENTRIES = 0

local function isInline(location: syntax.Span): boolean
	return location.beginLine == location.endLine
end

-- `return { ok = true } :: Result` and `return ({ ok = true })` still return
-- the table, so casts and parentheses are looked through.
local function unwrap(expr: syntax.CstExpr): syntax.CstExpr
	local current = expr
	while true do
		local cast = utils.isExprTypeAssertion(current)
		local group = utils.isExprGroup(current)
		if cast then
			current = cast.operand
		elseif group then
			current = group.expression
		else
			return current
		end
	end
end

local function collectReturnedTables(cst: syntax.CstStatBlock): { [syntax.CstExprTable]: true }
	local returned: { [syntax.CstExprTable]: true } = {}
	query.findAllFromRoot(cst, utils.isStatReturn):forEach(function(statement)
		for _, expr in statement.expressions do
			local tbl = utils.isExprTable(unwrap(expr))
			if tbl then
				returned[tbl] = true
			end
		end
	end)
	return returned
end

local function createViolation(location: syntax.Span, message: string, sourcepath: path.Path?): types.LintViolation
	return {
		lintname = NAME,
		location = location,
		message = message,
		severity = "warning",
		sourcepath = sourcepath,
	}
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}
	local returned = collectReturnedTables(cst)

	-- Lute crashes on a report whose location lies inside a table type
	-- (flipbook-labs/code-quality#14), which a constructor can, as in
	-- `typeof({ 1, 2, 3, 4 })`. `getReportLocation` widens such a report to
	-- the outermost table type and leaves the rest unchanged.
	query.findAllFromRoot(cst, utils.isExprTable):forEach(function(tbl)
		if not isInline(tbl.location) then
			return
		end
		local message: string? = nil
		if returned[tbl] and #tbl.entries > MAX_INLINE_RETURNED_ENTRIES then
			message = "Put each entry of a returned table on its own line."
		elseif #tbl.entries > MAX_INLINE_ENTRIES then
			message = "Put each entry on its own line when a table has more than three entries."
		end
		-- `getReportLocation` searches the whole file, so it only runs for a
		-- table that gets reported.
		if message then
			table.insert(violations, createViolation(getReportLocation(cst, tbl.location), message, sourcepath))
		end
	end)

	-- A table type nested in another is widened the same way.
	query.findAllFromRoot(cst, utils.isTypeTable):forEach(function(tableType)
		if isInline(tableType.location) and #tableType.entries > MAX_INLINE_ENTRIES then
			table.insert(
				violations,
				createViolation(
					getReportLocation(cst, tableType.location),
					"Put each entry on its own line when a table type has more than three entries.",
					sourcepath
				)
			)
		end
	end)

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

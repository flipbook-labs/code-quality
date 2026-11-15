local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../types")

local NAME = "inline_table"

-- One or two keyed fields still read well on one line. From three on, each
-- field gets its own line so the table is easy to scan and diffs stay small.
-- A table that a function returns is that function's result, so it's always
-- expanded, even with a single keyed field.
local MAX_INLINE_KEYED_FIELDS = 2
local MAX_INLINE_RETURNED_KEYED_FIELDS = 0

local function countKeyedFields(tbl: syntax.CstExprTable): number
	local count = 0
	for _, entry in tbl.entries do
		if entry.kind == "record" or entry.kind == "general" then
			count += 1
		end
	end
	return count
end

local function isInline(tbl: syntax.CstExprTable): boolean
	return tbl.location.beginLine == tbl.location.endLine
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

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local returned = collectReturnedTables(cst)

	return query.findAllFromRoot(cst, utils.isExprTable):mapToArray(function(tbl): types.LintViolation?
		local isReturned = returned[tbl] == true
		local limit = if isReturned then MAX_INLINE_RETURNED_KEYED_FIELDS else MAX_INLINE_KEYED_FIELDS
		if not isInline(tbl) or countKeyedFields(tbl) <= limit then
			return nil
		end
		return {
			lintname = NAME,
			location = tbl.location,
			message = if isReturned
				then "Put each field of a returned table on its own line."
				else `Put each field on its own line when a table has more than {MAX_INLINE_KEYED_FIELDS} keyed fields.`,
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

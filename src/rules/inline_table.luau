local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../types")

local NAME = "inline_table"

-- One or two keyed fields still read well on one line. From three on, each
-- field gets its own line so the table is easy to scan and diffs stay small.
local MAX_INLINE_KEYED_FIELDS = 2

local function countKeyedFields(tbl: syntax.CstExprTable): number
	local count = 0
	for _, entry in tbl.entries do
		if entry.kind == "record" or entry.kind == "general" then
			count += 1
		end
	end
	return count
end

local function isInlineWithManyKeys(tbl: syntax.CstExprTable): boolean
	return tbl.location.beginLine == tbl.location.endLine and countKeyedFields(tbl) > MAX_INLINE_KEYED_FIELDS
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	return query
		.findAllFromRoot(cst, utils.isExprTable)
		:filter(isInlineWithManyKeys)
		:mapToArray(function(tbl): types.LintViolation?
			return {
				lintname = NAME,
				location = tbl.location,
				message = `Put each field on its own line when a table has more than {MAX_INLINE_KEYED_FIELDS} keyed fields.`,
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

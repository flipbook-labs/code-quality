local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getReportLocation = require("../lib/getReportLocation")
local types = require("../types")

local NAME = "no_error_field"
local MESSAGE =
	"Name error fields `err` or `problem`. `error` reads as the global function and says little about what the field holds."

local function createViolation(location: syntax.Span, sourcepath: path.Path?): types.LintViolation
	return {
		lintname = NAME,
		location = location,
		message = MESSAGE,
		severity = "warning",
		sourcepath = sourcepath,
	}
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isExprTable):forEach(function(tbl)
		for _, entry in tbl.entries do
			if entry.kind == "record" then
				if entry.key.text == "error" then
					table.insert(violations, createViolation(entry.key.location, sourcepath))
				end
			elseif entry.kind == "general" then
				local key = utils.isExprConstantString(entry.key)
				if key and key.value.text == "error" then
					table.insert(violations, createViolation(key.location, sourcepath))
				end
			end
		end
	end)

	query.findAllFromRoot(cst, utils.isTypeTable):forEach(function(tableType)
		for _, entry in tableType.entries do
			if entry.kind == "property" and entry.key.text == "error" then
				table.insert(violations, createViolation(getReportLocation(cst, entry.key.location), sourcepath))
			end
		end
	end)

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

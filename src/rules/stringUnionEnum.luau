local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../types")

local NAME = "string_union_enum"

-- Two literals read fine as a union. From three on, a frozen table of named
-- constants keeps callers from repeating raw strings.
local MIN_MEMBERS = 3

local function isStringLiteralUnion(union: syntax.CstTypeUnion): boolean
	if #union.types < MIN_MEMBERS then
		return false
	end
	for _, member in union.types do
		if not utils.isTypeSingletonString(member) then
			return false
		end
	end
	return true
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	return query
		.findAllFromRoot(cst, utils.isStatTypeAlias)
		:filter(function(alias)
			local union = utils.isTypeUnion(alias.type)
			return alias.isExported and union ~= nil and isStringLiteralUnion(union)
		end)
		:mapToArray(function(alias): types.LintViolation?
			return {
				lintname = NAME,
				location = alias.location,
				message = `Define \`{alias.name.text}\`'s values as a frozen table of named constants, and use those instead of the raw strings.`,
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

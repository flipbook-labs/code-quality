local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getStringMethodName = require("../lib/getStringMethodName")
local types = require("../types")

local NAME = "string_method_call"

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	return query.findAllFromRoot(cst, utils.isExprCall):mapToArray(function(call): types.LintViolation?
		local method = getStringMethodName(call)
		if not method then
			return nil
		end

		return {
			lintname = NAME,
			location = call.location,
			message = `Use colon notation: \`value:{method}(...)\` instead of \`string.{method}(value, ...)\`.`,
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

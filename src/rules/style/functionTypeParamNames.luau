local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

local NAME = "function_type_param_names"

local function hasUnnamedParameter(functionType: syntax.CstTypeFunction): boolean
	for _, parameter in functionType.parameters do
		if parameter.name == nil then
			return true
		end
	end
	return false
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	return query
		.findAllFromRoot(cst, utils.isTypeFunction)
		:filter(hasUnnamedParameter)
		:mapToArray(function(functionType): types.LintViolation?
			return {
				lintname = NAME,
				location = getReportLocation(cst, functionType.location),
				message = "Name the parameters in function types, as in `(storyModule: ModuleScript) -> ()`, so the type reads as a signature.",
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

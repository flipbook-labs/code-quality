local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getReportLocation = require("../lib/getReportLocation")
local types = require("../types")

local NAME = "no_any"

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	return query
		.findAllFromRoot(cst, utils.isTypeReference)
		:filter(function(reference)
			return reference.name.text == "any" and reference.prefix == nil
		end)
		:mapToArray(function(reference): types.LintViolation?
			return {
				lintname = NAME,
				location = getReportLocation(cst, reference.location),
				message = "Prefer `unknown` over `any`. `unknown` keeps type checking on and makes callers narrow the value before using it.",
				severity = "warning",
				sourcepath = sourcepath,
				suggestedfix = {
					location = reference.location,
					fix = "unknown",
				},
			}
		end)
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local argumentSource = require("../../lib/argumentSource")
local constructorArguments = require("../../lib/robloxConstructorCall")
local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

local NAME = "roblox_incorrect_color3_new_bounds"

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isExprCall):forEach(function(call)
		local arguments = constructorArguments(call, "Color3")
		if not arguments then
			return
		end

		for _, argument in arguments do
			local value = argumentSource.decimal(argument)
			if value ~= nil and (value < 0 or value > 1) then
				local violation: types.LintViolation = {
					lintname = NAME,
					location = getReportLocation(cst, argument.location),
					message = "Color3.new only takes numbers from 0 to 1. Did you mean to use `Color3.fromRGB` instead?",
					severity = "warning",
					sourcepath = sourcepath,
				}
				table.insert(violations, violation)
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

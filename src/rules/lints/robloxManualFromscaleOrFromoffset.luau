local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local argumentSource = require("../../lib/argumentSource")
local constructorArguments = require("../../lib/robloxConstructorCall")
local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

local NAME = "roblox_manual_fromscale_or_fromoffset"

-- Whether `expr` is a number that is exactly zero. `-0` counts, as it does in
-- Selene's float comparison.
local function isZero(expr: syntax.CstExpr): boolean
	return argumentSource.decimal(expr) == 0
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isExprCall):forEach(function(call)
		local arguments = constructorArguments(call, "UDim2")
		if not arguments or #arguments ~= 4 then
			return
		end

		-- UDim2.new takes x scale, x offset, y scale, y offset, in that order.
		local xScale, xOffset, yScale, yOffset = arguments[1], arguments[2], arguments[3], arguments[4]

		local onlyOffset = isZero(xScale) and isZero(yScale)
		local onlyScale = isZero(xOffset) and isZero(yOffset)

		-- All four zero is a valid way to write the origin, so there's nothing to simplify.
		if onlyOffset and onlyScale then
			return
		end

		local message: string
		if onlyOffset then
			local x = argumentSource.text(xOffset)
			local y = argumentSource.text(yOffset)
			message =
				`This UDim2.new call only sets offset, and can be simplified using UDim2.fromOffset. Try: UDim2.fromOffset({x}, {y})`
		elseif onlyScale then
			local x = argumentSource.text(xScale)
			local y = argumentSource.text(yScale)
			message =
				`This UDim2.new call only sets scale, and can be simplified using UDim2.fromScale. Try: UDim2.fromScale({x}, {y})`
		else
			return
		end

		local violation: types.LintViolation = {
			lintname = NAME,
			location = getReportLocation(cst, call.location),
			message = message,
			severity = "warning",
			sourcepath = sourcepath,
		}
		table.insert(violations, violation)
	end)

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

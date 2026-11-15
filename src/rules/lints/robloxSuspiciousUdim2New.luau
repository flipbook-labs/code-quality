local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local argumentSource = require("../../lib/argumentSource")
local constructorArguments = require("../../lib/robloxConstructorCall")
local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

local NAME = "roblox_suspicious_udim2_new"

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isExprCall):forEach(function(call)
		local arguments = constructorArguments(call, "UDim2")
		if not arguments then
			return
		end

		local provided = #arguments
		-- Zero arguments and four or more are both fine, so only one to three are checked.
		if provided == 0 or provided >= 4 then
			return
		end

		-- Only literal numbers count, so `-1` doesn't, as in Selene.
		local numberCount = 0
		local allBetweenZeroAndOne = true
		for _, argument in arguments do
			if utils.isExprConstantNumber(argument) then
				numberCount += 1
			end

			local value = argumentSource.decimal(argument)
			if value == nil or value < 0 or value > 1 then
				allBetweenZeroAndOne = false
			end
		end

		-- Two non-number arguments are most likely `UDim2.new(UDim.new(), UDim.new())`,
		-- so that's left alone.
		if provided == 2 and numberCount == 0 then
			return
		end

		local allNumbers = numberCount == provided
		local wasOrWere = if provided == 1 then "was" else "were"
		local message = `UDim2.new takes 4 numbers, but {provided} {wasOrWere} provided.`

		-- A hint is only useful when the arguments are all numbers, since the
		-- right constructor depends on the values being scale or offset.
		if provided <= 2 and allNumbers then
			if allBetweenZeroAndOne then
				message ..= " Did you mean to use UDim2.fromScale instead?"
			else
				message ..= " Did you mean to use UDim2.fromOffset instead?"
			end
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

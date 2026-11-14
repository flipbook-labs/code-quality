local path = require("@std/path")
local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../types")

local NAME = "tostring_in_interpolation"

-- Returns the call when `expr` is `tostring(x)` with exactly one argument.
local function getTostringCall(expr: syntax.CstExpr): syntax.CstExprCall?
	local call = utils.isExprCall(expr)
	if not call or #call.arguments ~= 1 then
		return nil
	end

	local global = utils.isExprGlobal(call.func)
	if not global or global.name.text ~= "tostring" then
		return nil
	end

	return call
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isExprInterpString):forEach(function(interpolation)
		for _, expr in interpolation.expressions do
			local call = getTostringCall(expr)
			if call then
				local violation: types.LintViolation = {
					lintname = NAME,
					location = call.location,
					message = "Interpolated strings already call `tostring` on each value, so the wrapper can go.",
					severity = "warning",
					sourcepath = sourcepath,
					suggestedfix = {
						fix = printer.printNode(call.arguments[1]),
					},
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

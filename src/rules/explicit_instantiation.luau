local path = require("@std/path")
local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local isLiteral = require("../lib/isLiteral")
local types = require("../types")

local NAME = "explicit_instantiation"

-- Casting a literal argument, as in `useState(nil :: string?)`, is how a
-- generic function's type parameter used to be set before Luau had explicit
-- instantiation. A cast on a literal does nothing else, so it's a reliable
-- sign that `useState<<string?>>(nil)` is what the code means.
local function getLiteralCast(expr: syntax.CstExpr): syntax.CstExprTypeAssertion?
	local cast = utils.isExprTypeAssertion(expr)
	if cast and isLiteral(cast.operand) then
		return cast
	end
	return nil
end

local function printTrimmed(node: syntax.CstNode): string
	local text = printer.printNode(node):gsub("^%s+", ""):gsub("%s+$", "")
	return text
end

-- A fix is only offered when the cast is the call's sole argument. With more
-- arguments, the function may have several type parameters, and there's no
-- way to tell from the call which one the cast was steering.
local function getSuggestedFix(call: syntax.CstExprCall, cast: syntax.CstExprTypeAssertion): types.SuggestedFix?
	if #call.arguments ~= 1 then
		return nil
	end
	return {
		fix = `{printTrimmed(call.func)}<<{printTrimmed(cast.annotation)}>>({printTrimmed(cast.operand)})`,
	}
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isExprCall):forEach(function(call)
		for _, argument in call.arguments do
			local cast = getLiteralCast(argument)
			if cast then
				local violation: types.LintViolation = {
					lintname = NAME,
					location = call.location,
					message = "Set the type parameter with explicit instantiation, as in `useState<<string?>>(nil)`, instead of casting a literal argument.",
					severity = "warning",
					sourcepath = sourcepath,
					suggestedfix = getSuggestedFix(call, cast),
				}
				table.insert(violations, violation)
				break
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

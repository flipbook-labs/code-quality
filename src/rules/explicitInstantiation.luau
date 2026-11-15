local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local isLiteral = require("../lib/isLiteral")
local types = require("../types")

local NAME = "explicit_instantiation"

-- Casting a literal argument, as in `useState(nil :: string?)`, is how a
-- generic function's type parameter used to be set before Luau had explicit
-- instantiation. A cast on a literal does nothing else, so it's a reliable
-- sign that explicit instantiation is what the code means.
--
-- The rule offers no fix because the cast's type isn't always the type
-- parameter. For `first(items: { T }): T?`, the call `first({} :: { number })`
-- means `first<<number>>({})`, and only the function's signature says so.
local function getLiteralCast(expr: syntax.CstExpr): syntax.CstExprTypeAssertion?
	local cast = utils.isExprTypeAssertion(expr)
	if cast and isLiteral(cast.operand) then
		return cast
	end
	return nil
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

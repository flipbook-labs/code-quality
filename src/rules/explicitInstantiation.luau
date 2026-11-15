local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local isLiteral = require("../lib/isLiteral")
local types = require("../types")

local NAME = "explicit_instantiation"

-- Casts like React's dependency arrays, `{ value, setValue } :: { unknown }`,
-- widen a table of mixed values to `{ unknown }` or `{ any }` rather than set a
-- type parameter. Luau's old type solver rejects the mixed table without one.
local function isUntypedArrayCast(cast: syntax.CstExprTypeAssertion): boolean
	local array = utils.isTypeArray(cast.annotation)
	if not array or not utils.isExprTable(cast.operand) then
		return false
	end
	local element = utils.isTypeReference(array.type)
	return element ~= nil and element.prefix == nil and (element.name.text == "unknown" or element.name.text == "any")
end

-- Casting a literal argument, as in `useState(nil :: string?)`, is how a
-- generic function's type parameter used to be set before Luau had explicit
-- instantiation. Apart from widening an untyped array, a cast on a literal does
-- nothing else, so it's a reliable sign that explicit instantiation is what the
-- code means.
--
-- The rule offers no fix because the cast's type isn't always the type
-- parameter. For `first(items: { T }): T?`, the call `first({} :: { number })`
-- means `first<<number>>({})`, and only the function's signature says so.
local function getLiteralCast(expr: syntax.CstExpr): syntax.CstExprTypeAssertion?
	local cast = utils.isExprTypeAssertion(expr)
	if cast and isLiteral(cast.operand) and not isUntypedArrayCast(cast) then
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

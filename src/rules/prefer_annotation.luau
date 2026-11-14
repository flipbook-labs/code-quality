local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local isLiteral = require("../lib/isLiteral")
local types = require("../types")

local NAME = "prefer_annotation"

-- `local items = {} :: { Item }` casts a literal only to give the local a
-- type. Annotating the local, `local items: { Item } = {}`, does that without
-- a cast, and the checker then verifies the value instead of trusting it.
local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isStatLocal):forEach(function(statement)
		for index, variable in statement.variables do
			local value = statement.values[index]
			local cast = if value then utils.isExprTypeAssertion(value) else nil
			if cast and variable.annotation == nil and isLiteral(cast.operand) then
				local violation: types.LintViolation = {
					lintname = NAME,
					location = cast.location,
					message = `Annotate \`{variable.name.text}\` instead of casting its initial value.`,
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

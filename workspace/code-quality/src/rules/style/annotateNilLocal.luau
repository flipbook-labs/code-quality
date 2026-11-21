local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../../types")

local NAME = "annotate_nil_local"

-- A local that starts as `nil` gives the checker nothing to infer its type
-- from, so it needs an annotation to say what it will hold.

-- Whether the variable at `index` starts as nil. A variable past the end of
-- the value list is nil, unless the last value is a call or `...`, which can
-- fill the remaining variables with its extra return values.
local function startsNil(statement: syntax.CstStatLocal, index: number): boolean
	local value = statement.values[index]
	if value then
		return utils.isExprConstantNil(value) ~= nil
	end

	local last = statement.values[#statement.values]
	if last and (utils.isExprCall(last) or utils.isExprVarargs(last)) then
		return false
	end
	return true
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isStatLocal):forEach(function(statement)
		for index, variable in statement.variables do
			if variable.annotation == nil and startsNil(statement, index) then
				local violation: types.LintViolation = {
					lintname = NAME,
					location = variable.location,
					message = `Annotate \`{variable.name.text}\`, since it starts as nil.`,
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

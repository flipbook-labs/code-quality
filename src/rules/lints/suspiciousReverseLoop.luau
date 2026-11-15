local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../../types")

local NAME = "suspicious_reverse_loop"

-- `for i = #items, 1 do` looks like it walks `items` backwards, but without a
-- step of `-1` it counts up from `#items` and stops at once.
local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	return query.findAllFromRoot(cst, utils.isStatFor):mapToArray(function(loop): types.LintViolation?
		if loop.step ~= nil then
			return nil
		end

		local from = utils.isExprUnary(loop.from)
		local to = utils.isExprConstantNumber(loop.to)
		if not from or from.operator.text ~= "#" or not to or to.value > 1 then
			return nil
		end

		return {
			lintname = NAME,
			location = syntax.span.create({
				beginLine = loop.from.location.beginLine,
				beginColumn = loop.from.location.beginColumn,
				endLine = loop.to.location.endLine,
				endColumn = loop.to.location.endColumn,
			}),
			message = "This loop runs once at most. To count down, add `, -1` after the end value.",
			severity = "warning",
			sourcepath = sourcepath,
		}
	end)
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

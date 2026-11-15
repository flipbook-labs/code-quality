local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../types")

local NAME = "string_method_call"

local STRING_METHODS = table.freeze({
	"byte",
	"find",
	"format",
	"gmatch",
	"gsub",
	"len",
	"lower",
	"match",
	"rep",
	"reverse",
	"split",
	"sub",
	"upper",
})

-- A call is flagged only when its first argument is a value. With a literal,
-- as in `string.rep("-", 20)` or `string.format("%d", n)`, the free-function
-- form reads better than `("-"):rep(20)`.
local function isStringLiteral(expr: syntax.CstExpr): boolean
	return utils.isExprConstantString(expr) ~= nil or utils.isExprInterpString(expr) ~= nil
end

local function getFreeFunctionName(call: syntax.CstExprCall): string?
	local index = utils.isExprIndexName(call.func)
	if not index or index.accessor.text ~= "." then
		return nil
	end

	local base = utils.isExprGlobal(index.expression)
	if not base or base.name.text ~= "string" or not table.find(STRING_METHODS, index.index.text) then
		return nil
	end

	local firstArgument = call.arguments[1]
	if firstArgument == nil or isStringLiteral(firstArgument) then
		return nil
	end

	return index.index.text
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	return query.findAllFromRoot(cst, utils.isExprCall):mapToArray(function(call): types.LintViolation?
		local method = getFreeFunctionName(call)
		if not method then
			return nil
		end

		return {
			lintname = NAME,
			location = call.location,
			message = `Use colon notation: \`value:{method}(...)\` instead of \`string.{method}(value, ...)\`.`,
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

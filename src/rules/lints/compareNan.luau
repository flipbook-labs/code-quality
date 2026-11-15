local path = require("@std/path")
local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

local NAME = "compare_nan"

-- NaN is the only value that isn't equal to itself, so `x == 0/0` is always
-- false and `x ~= 0/0` is always true. This returns the operator for the
-- self-comparison that does what the author meant, as in `x ~= x`.
local function getReplacementOperator(operator: string): string?
	if operator == "==" then
		return "~="
	elseif operator == "~=" then
		return "=="
	end
	return nil
end

local function isZero(expr: syntax.CstExpr): boolean
	local number = utils.isExprConstantNumber(expr)
	return number ~= nil and number.token.text == "0"
end

-- Like Selene, this only recognizes NaN spelled `0/0`.
local function isNan(expr: syntax.CstExpr): boolean
	local binary = utils.isExprBinary(expr)
	return binary ~= nil and binary.operator.text == "/" and isZero(binary.lhsOperand) and isZero(binary.rhsOperand)
end

-- Selene only flags a variable on the left: a name or an index like `a.b` or
-- `a[b]`. A call result, a literal, or a parenthesized expression is left
-- alone.
local function isVariable(expr: syntax.CstExpr): boolean
	return utils.isExprGlobal(expr) ~= nil
		or utils.isExprLocal(expr) ~= nil
		or utils.isExprIndexName(expr) ~= nil
		or utils.isExprIndexExpr(expr) ~= nil
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	return query.findAllFromRoot(cst, utils.isExprBinary):mapToArray(function(binary): types.LintViolation?
		local replacement = getReplacementOperator(binary.operator.text)
		if not replacement or not isVariable(binary.lhsOperand) or not isNan(binary.rhsOperand) then
			return nil
		end

		local variable = printer.printNode(binary.lhsOperand):match("^%s*(.-)%s*$")
		return {
			lintname = NAME,
			location = getReportLocation(cst, binary.location),
			message = `Comparing a value to NaN never works, since NaN isn't equal to anything. Use \`{variable} {replacement} {variable}\` instead.`,
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

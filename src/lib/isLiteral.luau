local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

-- Whether `expr` is a literal value: `nil`, a boolean, a number, a string, or
-- a table constructor.
local function isLiteral(expr: syntax.CstExpr): boolean
	return utils.isExprConstantNil(expr) ~= nil
		or utils.isExprConstantBool(expr) ~= nil
		or utils.isExprConstantNumber(expr) ~= nil
		or utils.isExprConstantString(expr) ~= nil
		or utils.isExprTable(expr) ~= nil
end

return isLiteral

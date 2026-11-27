local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

-- Returns the expression inside any parentheses around `expr`, so `((f()))`
-- gives back `f()`. An expression without parentheses comes back unchanged.
local function unwrapGroups(expr: syntax.CstExpr): syntax.CstExpr
	local group = utils.isExprGroup(expr)
	while group do
		expr = group.expression
		group = utils.isExprGroup(expr)
	end
	return expr
end

return unwrapGroups

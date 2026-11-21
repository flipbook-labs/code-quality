local syntax = require("@std/syntax")

-- Whether evaluating `expr` could have side effects, following Selene's rules.
-- Calls always count. Indexing is judged by what it indexes, not by the key:
-- Selene does not look inside `t[f()]`, so that case is treated as safe here
-- too, to keep the same results.
local function exprHasSideEffects(expr: syntax.CstExpr): boolean
	if expr.tag == "group" or expr.tag == "indexname" or expr.tag == "index" then
		return exprHasSideEffects(expr.expression)
	elseif
		expr.tag == "nil"
		or expr.tag == "boolean"
		or expr.tag == "number"
		or expr.tag == "string"
		or expr.tag == "local"
		or expr.tag == "global"
		or expr.tag == "vararg"
		or expr.tag == "function"
	then
		return false
	elseif expr.tag == "call" then
		return true
	elseif expr.tag == "instantiate" then
		return exprHasSideEffects(expr.expr)
	elseif expr.tag == "unary" or expr.tag == "cast" then
		return exprHasSideEffects(expr.operand)
	elseif expr.tag == "binary" then
		return exprHasSideEffects(expr.lhsOperand) or exprHasSideEffects(expr.rhsOperand)
	elseif expr.tag == "interpolatedstring" then
		for _, inner in expr.expressions do
			if exprHasSideEffects(inner) then
				return true
			end
		end
		return false
	elseif expr.tag == "table" then
		for _, entry in expr.entries do
			if entry.kind == "general" then
				if exprHasSideEffects(entry.key) or exprHasSideEffects(entry.value) then
					return true
				end
			elseif exprHasSideEffects(entry.value) then
				return true
			end
		end
		return false
	elseif expr.tag == "conditional" then
		if
			exprHasSideEffects(expr.condition)
			or exprHasSideEffects(expr.thenExpr)
			or exprHasSideEffects(expr.elseExpr)
		then
			return true
		end
		for _, branch in expr.elseifs do
			if exprHasSideEffects(branch.condition) or exprHasSideEffects(branch.thenExpr) then
				return true
			end
		end
		return false
	end
	-- Anything else is unknown, so assume it has side effects, as Selene does.
	return true
end

return exprHasSideEffects

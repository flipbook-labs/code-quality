-- Replaces expressions whose value is known before the program runs with that
-- value, replacing darklua's `compute_expression` rule. `2 * 60 * 1000`
-- becomes `120000`, and `"prod" == "development"` becomes `false`.
--
-- As in darklua, only unary, binary, and `if` expressions are folded into a
-- literal, and only when they have no side effects and their value is known
-- from the literals in them. `and` and `or`
-- also fold when their left side is known, keeping the side that decides the
-- result: `true and value` becomes `value`, and `nil or value` becomes
-- `value`.
--
-- This differs from darklua in a few places, none of which change what the
-- code does:
--
-- - Numbers are written the way `tostring` writes them, so `-1000` stays
--   `-1000` where darklua writes `-1E3`. Infinity and NaN are written as
--   `(1/0)` and `(0/0)`.
-- - Arithmetic and string conversion run on Luau's own operators, so `0.1 + 0.2`
--   folds to exactly the number Luau would compute. Darklua compares numbers
--   within a small tolerance and formats them with Rust.
-- - When `and` or `or` keeps a call or `...`, the call gets parentheses.
--   `return true and f()` returns one value, and darklua's `return f()`
--   would return all of them.
--
-- Run it with `lute transform <package>/src/mods/computeExpression.luau <files>`.

local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")
local transformTypes = require("@std/commands/transform/types")
local visitor = require("@std/syntax/visitor")

local codemodEdits = require("../lib/codemodEdits")
local evaluator = require("../lib/evaluator")

local function transform(context: transformTypes.Context): syntaxTypes.Replacements
	local replacements: syntaxTypes.Replacements = {}
	local operandContexts = codemodEdits.findOperandContexts(context.parseresult)
	local folder = visitor.create()

	-- For `a and b` or `a or b` with a known left side, returns whichever
	-- side gives the result, with the expressions inside it folded too.
	local function keepDecidingSide(operator: string, expr: syntax.CstExprBinary): string?
		if (operator ~= "and" and operator ~= "or") or evaluator.hasSideEffects(expr.lhsOperand) then
			return nil
		end

		local truthy = evaluator.isTruthy(evaluator.evaluate(expr.lhsOperand))
		if truthy == nil then
			return nil
		end

		local keepLeft = if operator == "and" then not truthy else truthy
		local kept = if keepLeft then expr.lhsOperand else expr.rhsOperand
		visitor.visitExpression(kept, folder)

		local text = codemodEdits.printWithoutTrivia(kept, replacements)
		return if evaluator.canReturnMultipleValues(kept) then `({text})` else text
	end

	local function fold(expr: syntax.CstExpr): string?
		if expr.tag ~= "unary" and expr.tag ~= "binary" and expr.tag ~= "conditional" then
			return nil
		end

		if not evaluator.hasSideEffects(expr) then
			local literal = evaluator.toLiteral(evaluator.evaluate(expr))
			if literal then
				return literal
			end
		end

		return if expr.tag == "binary" then keepDecidingSide(expr.operator.text, expr) else nil
	end

	-- Expressions are folded from the outside in. Once one is replaced, the
	-- expressions inside it are gone, so the visitor doesn't go into it.
	function folder.visitExpr(expr: syntax.CstExpr): boolean
		local text = fold(expr)
		if text then
			replacements[expr] = codemodEdits.fitReplacement(expr, text, operandContexts)
			return false
		end
		return true
	end

	visitor.visitBlock(context.parseresult.root, folder)
	return replacements
end

local migration: transformTypes.Migration = {
	transform = transform,
}

return table.freeze(migration)

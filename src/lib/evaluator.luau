-- Works out what an expression evaluates to without running the program, for
-- the code mods that replace darklua's `compute_expression`,
-- `remove_unused_if_branch`, and `remove_unused_while` rules. It ports
-- darklua's evaluator, so these mods fold the same expressions darklua does.
--
-- An expression's value is known when it's built from literals, like
-- `2 * 60` or `"prod" == "dev"`. Reading a name, a field, or a call gives an
-- unknown value. An `and` or `or` is still known when its known side decides
-- the result, as in `false and f()`, since `f` never runs. The arithmetic
-- itself runs on Luau's own operators, so a folded result is exactly what the
-- expression would give at runtime.

local luau = require("@std/luau")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

export type Value =
	{ kind: "unknown" }
	| { kind: "nil" }
	| { kind: "boolean", value: boolean }
	| { kind: "number", value: number }
	| { kind: "string", value: string }
	| { kind: "function" }
	| { kind: "table" }

local UNKNOWN: Value = { kind = "unknown" }
local NIL: Value = { kind = "nil" }
local FUNCTION: Value = { kind = "function" }
local TABLE: Value = { kind = "table" }

local function boolean(value: boolean): Value
	return {
		kind = "boolean",
		value = value,
	}
end

local function number(value: number): Value
	return {
		kind = "number",
		value = value,
	}
end

local function str(value: string): Value
	return {
		kind = "string",
		value = value,
	}
end

-- Whether `value` counts as true in a condition: `false` for `nil` and
-- `false`, `true` for anything else, and `nil` when the value is unknown.
local function isTruthy(value: Value): boolean?
	if value.kind == "unknown" then
		return nil
	elseif value.kind == "nil" then
		return false
	elseif value.kind == "boolean" then
		return value.value
	end
	return true
end

-- The CST keeps string literals as they're written, escapes and all. Running
-- the literal as a one-line chunk decodes it the way Luau would. The chunk
-- gets an empty environment, and a literal can't call anything anyway.
local function decodeLiteral(literalSource: string): string?
	local ok, result = pcall(function()
		return luau.load(luau.compile(`return {literalSource}`), "literal", {})()
	end)
	return if ok and typeof(result) == "string" then result else nil
end

local function stringLiteralValue(expr: syntax.CstExprConstantString): string?
	if expr.quoteStyle == "block" then
		local equals = string.rep("=", expr.blockDepth)
		return decodeLiteral(`[{equals}[{expr.value.text}]{equals}]`)
	end
	local quote = if expr.quoteStyle == "single" then "'" else '"'
	return decodeLiteral(`{quote}{expr.value.text}{quote}`)
end

-- Arithmetic coerces strings that look like numbers, as Luau does at runtime.
local function toNumber(value: Value): number?
	if value.kind == "number" then
		return value.value
	elseif value.kind == "string" then
		return tonumber(value.value)
	end
	return nil
end

local evaluate: (expr: syntax.CstExpr) -> Value

local function evaluateEqual(left: Value, right: Value): Value
	if left.kind == "unknown" or right.kind == "unknown" then
		return UNKNOWN
	elseif left.kind ~= right.kind then
		return boolean(false)
	elseif left.kind == "nil" then
		return boolean(true)
	elseif left.kind == "boolean" and right.kind == "boolean" then
		return boolean(left.value == right.value)
	elseif left.kind == "number" and right.kind == "number" then
		return boolean(left.value == right.value)
	elseif left.kind == "string" and right.kind == "string" then
		return boolean(left.value == right.value)
	end
	-- Two constructors always make two different functions or tables.
	return boolean(false)
end

local ARITHMETIC: { [string]: (left: number, right: number) -> number } = {
	["+"] = function(a, b)
		return a + b
	end,
	["-"] = function(a, b)
		return a - b
	end,
	["*"] = function(a, b)
		return a * b
	end,
	["/"] = function(a, b)
		return a / b
	end,
	["//"] = function(a, b)
		return a // b
	end,
	["%"] = function(a, b)
		return a % b
	end,
	["^"] = function(a, b)
		return a ^ b
	end,
}

local function compare(operator: string, a: number | string, b: number | string): boolean
	-- Luau compares two numbers or two strings with the same operators, so
	-- the casts only satisfy the type checker.
	local left, right = a :: number, b :: number
	if operator == "<" then
		return left < right
	elseif operator == "<=" then
		return left <= right
	elseif operator == ">" then
		return left > right
	end
	return left >= right
end

local function evaluateBinary(operator: string, expr: syntax.CstExprBinary): Value
	local left = evaluate(expr.lhsOperand)

	if operator == "and" then
		local truthy = isTruthy(left)
		if truthy == nil then
			return UNKNOWN
		end
		return if truthy then evaluate(expr.rhsOperand) else left
	elseif operator == "or" then
		local truthy = isTruthy(left)
		if truthy == nil then
			return UNKNOWN
		end
		return if truthy then left else evaluate(expr.rhsOperand)
	end

	local right = evaluate(expr.rhsOperand)
	if operator == "==" then
		return evaluateEqual(left, right)
	elseif operator == "~=" then
		local equal = evaluateEqual(left, right)
		return if equal.kind == "boolean" then boolean(not equal.value) else UNKNOWN
	end

	local arithmetic = ARITHMETIC[operator]
	if arithmetic then
		local a, b = toNumber(left), toNumber(right)
		return if a and b then number(arithmetic(a, b)) else UNKNOWN
	end

	if operator == ".." then
		local a = if left.kind == "number"
			then tostring(left.value)
			elseif left.kind == "string" then left.value
			else nil
		local b = if right.kind == "number"
			then tostring(right.value)
			elseif right.kind == "string" then right.value
			else nil
		return if a and b then str(a .. b) else UNKNOWN
	end

	if left.kind == "number" and right.kind == "number" then
		return boolean(compare(operator, left.value, right.value))
	elseif left.kind == "string" and right.kind == "string" then
		return boolean(compare(operator, left.value, right.value))
	end
	return UNKNOWN
end

local function evaluateUnary(operator: string, expr: syntax.CstExprUnary): Value
	local operand = evaluate(expr.operand)
	if operator == "not" then
		local truthy = isTruthy(operand)
		return if truthy == nil then UNKNOWN else boolean(not truthy)
	elseif operator == "-" then
		local value = toNumber(operand)
		return if value then number(-value) else UNKNOWN
	elseif operand.kind == "string" then
		return number(#operand.value)
	end
	return UNKNOWN
end

-- `if local x = f() then` binds a local from its condition. The evaluator
-- doesn't track locals, so a branch written that way counts as unknown.
local function evaluateIf(expr: syntax.CstExprIfElse): Value
	if expr.conditionLocal then
		return UNKNOWN
	end

	local truthy = isTruthy(evaluate(expr.condition))
	if truthy == nil then
		return UNKNOWN
	elseif truthy then
		return evaluate(expr.thenExpr)
	end

	for _, branch in expr.elseifs do
		local branchTruthy = if branch.conditionLocal then nil else isTruthy(evaluate(branch.condition))
		if branchTruthy == nil then
			return UNKNOWN
		elseif branchTruthy then
			return evaluate(branch.thenExpr)
		end
	end
	return evaluate(expr.elseExpr)
end

-- An interpolated string is known when every value in it is a literal that
-- `tostring` turns into the same text at runtime.
local function evaluateInterpString(expr: syntax.CstExprInterpString): Value
	local parts = {}
	for index, segment in expr.strings do
		local text = decodeLiteral(`\`{segment.text}\``)
		if not text then
			return UNKNOWN
		end
		table.insert(parts, text)

		local inner = expr.expressions[index]
		if inner then
			local value = evaluate(inner)
			if value.kind == "nil" then
				table.insert(parts, "nil")
			elseif value.kind == "boolean" or value.kind == "number" or value.kind == "string" then
				table.insert(parts, tostring(value.value))
			else
				return UNKNOWN
			end
		end
	end
	return str(table.concat(parts))
end

function evaluate(expr: syntax.CstExpr): Value
	if expr.tag == "nil" then
		return NIL
	elseif expr.tag == "boolean" then
		return boolean(expr.value)
	elseif expr.tag == "number" then
		return number(expr.value)
	elseif expr.tag == "string" then
		local value = stringLiteralValue(expr)
		return if value then str(value) else UNKNOWN
	elseif expr.tag == "function" then
		return FUNCTION
	elseif expr.tag == "table" then
		return TABLE
	elseif expr.tag == "group" then
		return evaluate(expr.expression)
	elseif expr.tag == "binary" then
		return evaluateBinary(expr.operator.text, expr)
	elseif expr.tag == "unary" then
		return evaluateUnary(expr.operator.text, expr)
	elseif expr.tag == "conditional" then
		return evaluateIf(expr)
	elseif expr.tag == "interpolatedstring" then
		return evaluateInterpString(expr)
	elseif expr.tag == "cast" then
		return evaluate(expr.operand)
	end
	return UNKNOWN
end

local hasSideEffects: (expr: syntax.CstExpr) -> boolean

-- An unknown value might be a table with a metatable, and an operator on it
-- would run a metamethod, which could do anything.
local function mightHaveMetatable(value: Value): boolean
	return value.kind == "unknown"
end

local function binaryHasSideEffects(operator: string, expr: syntax.CstExprBinary): boolean
	local leftEffects = hasSideEffects(expr.lhsOperand)
	if operator == "and" or operator == "or" then
		-- The right side only runs when the left side doesn't decide the
		-- result on its own.
		local truthy = isTruthy(evaluate(expr.lhsOperand))
		local skipsRight = if operator == "and" then truthy == false else truthy == true
		return leftEffects or (not skipsRight and hasSideEffects(expr.rhsOperand))
	end
	return mightHaveMetatable(evaluate(expr.lhsOperand))
		or mightHaveMetatable(evaluate(expr.rhsOperand))
		or leftEffects
		or hasSideEffects(expr.rhsOperand)
end

local function ifHasSideEffects(expr: syntax.CstExprIfElse): boolean
	if expr.conditionLocal or hasSideEffects(expr.condition) then
		return true
	end

	local truthy = isTruthy(evaluate(expr.condition))
	if truthy then
		return hasSideEffects(expr.thenExpr)
	elseif truthy == nil and hasSideEffects(expr.thenExpr) then
		return true
	end

	for _, branch in expr.elseifs do
		if branch.conditionLocal or hasSideEffects(branch.condition) then
			return true
		end
		local branchTruthy = if truthy == false then isTruthy(evaluate(branch.condition)) else nil
		if branchTruthy then
			return hasSideEffects(branch.thenExpr)
		elseif branchTruthy == nil and hasSideEffects(branch.thenExpr) then
			return true
		end
	end
	return hasSideEffects(expr.elseExpr)
end

-- Whether evaluating `expr` could do more than produce a value: call a
-- function, run a metamethod, or index something whose `__index` might. As in
-- darklua, reading a local or a global doesn't count, and indexing always
-- does.
function hasSideEffects(expr: syntax.CstExpr): boolean
	if
		expr.tag == "nil"
		or expr.tag == "boolean"
		or expr.tag == "number"
		or expr.tag == "string"
		or expr.tag == "function"
		or expr.tag == "local"
		or expr.tag == "global"
		or expr.tag == "vararg"
	then
		return false
	elseif expr.tag == "conditional" then
		return ifHasSideEffects(expr)
	elseif expr.tag == "binary" then
		return binaryHasSideEffects(expr.operator.text, expr)
	elseif expr.tag == "unary" then
		if expr.operator.text == "not" then
			return hasSideEffects(expr.operand)
		end
		return mightHaveMetatable(evaluate(expr.operand)) or hasSideEffects(expr.operand)
	elseif expr.tag == "group" then
		return hasSideEffects(expr.expression)
	elseif expr.tag == "cast" then
		return hasSideEffects(expr.operand)
	elseif expr.tag == "instantiate" then
		return hasSideEffects(expr.expr)
	elseif expr.tag == "table" then
		for _, entry in expr.entries do
			if hasSideEffects(entry.value) then
				return true
			elseif entry.kind == "general" and hasSideEffects(entry.key) then
				return true
			end
		end
		return false
	elseif expr.tag == "interpolatedstring" then
		-- Interpolation turns each value into a string with `tostring`, which
		-- runs `__tostring` on a value that might have a metatable.
		for _, inner in expr.expressions do
			if hasSideEffects(inner) or mightHaveMetatable(evaluate(inner)) then
				return true
			end
		end
		return false
	end
	-- Calls and indexes.
	return true
end

-- Whether `expr` can stand for more than one value, as a call or `...` does
-- at the end of a list. Moving one of those to the end of a list, or out of
-- an expression that kept only its first value, needs parentheses around it.
local function canReturnMultipleValues(expr: syntax.CstExpr): boolean
	return utils.isExprCall(expr) ~= nil or utils.isExprVarargs(expr) ~= nil
end

-- Writes a string as a double-quoted Luau literal that decodes back to it.
local function quoteString(value: string): string
	local escaped = value:gsub('[%c"\\]', function(char: string): string
		if char == "\n" then
			return "\\n"
		elseif char == "\r" then
			return "\\r"
		elseif char == "\t" then
			return "\\t"
		elseif char == '"' or char == "\\" then
			return `\\{char}`
		end
		return string.format("\\%03d", char:byte())
	end)
	return `"{escaped}"`
end

-- `tostring` writes the shortest text that reads back as the same number.
-- Infinity and NaN have no literal, so they're written as divisions, in
-- parentheses so they still read as one value wherever they land.
local function formatNumber(value: number): string
	if value ~= value then
		return "(0/0)"
	elseif value == math.huge then
		return "(1/0)"
	elseif value == -math.huge then
		return "(-1/0)"
	end
	return tostring(value)
end

-- Writes `value` as Luau source, or returns nil when it has no literal form,
-- as for a function or a table.
local function toLiteral(value: Value): string?
	if value.kind == "nil" then
		return "nil"
	elseif value.kind == "boolean" then
		return tostring(value.value)
	elseif value.kind == "number" then
		return formatNumber(value.value)
	elseif value.kind == "string" then
		return quoteString(value.value)
	end
	return nil
end

return table.freeze({
	evaluate = evaluate,
	formatNumber = formatNumber,
	isTruthy = isTruthy,
	hasSideEffects = hasSideEffects,
	canReturnMultipleValues = canReturnMultipleValues,
	toLiteral = toLiteral,
	quoteString = quoteString,
	stringLiteralValue = stringLiteralValue,
})

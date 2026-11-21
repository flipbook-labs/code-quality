local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

-- The functions in Luau's `string` library that a string value can also call
-- as a method, as in `value:find(...)`.
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

-- When the first argument is a string literal, as in `string.rep("-", 20)` or
-- `string.format("%d", n)`, the free function reads better than
-- `("-"):rep(20)`, so those calls are left as they are.
local function isStringLiteral(expr: syntax.CstExpr): boolean
	return utils.isExprConstantString(expr) ~= nil or utils.isExprInterpString(expr) ~= nil
end

-- When `call` calls a string library function on anything but a string
-- literal, as in `string.find(line, "x")`, returns the function's name
-- ("find"). Returns nil for every other call. The `string_method_call` rule
-- flags the calls this matches. Its code mod starts from the same calls and
-- rewrites the ones it can without changing what the code does.
local function getStringMethodName(call: syntax.CstExprCall): string?
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

return getStringMethodName

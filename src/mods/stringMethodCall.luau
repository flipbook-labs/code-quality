-- Rewrites `string.find(line, "x")` as `line:find("x")`. It changes the calls
-- the `string_method_call` rule flags, apart from the few below that it can't
-- rewrite without changing what the code does. The rule still flags those, so
-- they're easy to find and fix by hand.
--
-- Run it with `lute transform <package>/src/mods/stringMethodCall.luau <files>`.

local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")
local transformTypes = require("@std/commands/transform/types")
local trivia = require("@std/syntax/utils/trivia")
local utils = require("@std/syntax/utils")

local getStringMethodName = require("../lib/getStringMethodName")
local isLiteral = require("../lib/isLiteral")

-- Deletes a node along with the whitespace and comments around it.
local DELETE: syntaxTypes.Replacement = {
	content = "",
	preserveTrivia = false,
}

-- Whether `expr` can sit in front of `:method()` as it is. A name, an index,
-- a call, or a parenthesized expression can. Anything else, like `a .. b` or
-- `value :: string`, needs parentheses, or the method call would bind to only
-- part of it.
local function isPrefixExpression(expr: syntax.CstExpr): boolean
	return utils.isExprLocal(expr) ~= nil
		or utils.isExprGlobal(expr) ~= nil
		or utils.isExprIndexName(expr) ~= nil
		or utils.isExprIndexExpr(expr) ~= nil
		or utils.isExprCall(expr) ~= nil
		or utils.isExprGroup(expr) ~= nil
end

local function hasComment(triviaList: { syntax.Trivia }): boolean
	for _, item in triviaList do
		if item.tag ~= "whitespace" then
			return true
		end
	end
	return false
end

-- Whether moving the first argument in front of the call would change what
-- the code does or lose part of it.
local function canRewrite(call: syntax.CstExprCall): boolean
	local receiver = call.arguments[1]

	-- Only strings have methods, so `string.rep(5, 3)` works but `(5):rep(3)`
	-- throws. A literal of any other type would hit the same error.
	if isLiteral(receiver) then
		return false
	end

	-- A call or `...` as the only argument passes along every value it
	-- returns, so `string.sub(getRange())` might pass the string and both
	-- indices. As a receiver, it would keep only the first.
	local isOnlyArgument = #call.arguments == 1
	if isOnlyArgument and (utils.isExprCall(receiver) ~= nil or utils.isExprVarargs(receiver) ~= nil) then
		return false
	end

	-- The rewrite drops the whitespace around the first argument and its comma.
	-- A comment there would go with it, so those calls are left alone.
	local separator = call.arguments.separators[1]
	return not hasComment(trivia.leftmostTrivia(receiver))
		and not hasComment(trivia.rightmostTrivia(receiver))
		and not (separator and (hasComment(separator.leadingTrivia) or hasComment(separator.trailingTrivia)))
end

local function transform(context: transformTypes.Context): syntaxTypes.Replacements
	local replacements: syntaxTypes.Replacements = {}
	local calls = query.findAllFromRoot(context.parseresult, utils.isExprCall).nodes

	-- The query lists each call before the calls inside it. Working backwards
	-- rewrites the inner ones first, so when an outer call prints its receiver,
	-- as in `string.lower(string.sub(name, 1, 1))`, the receiver already reads
	-- `name:sub(1, 1)`.
	for i = #calls, 1, -1 do
		local call = calls[i]
		local method = getStringMethodName(call)
		if not method or not canRewrite(call) then
			continue
		end

		local receiver = call.arguments[1]
		local receiverText = printer.printNode(receiver, replacements):match("^%s*(.-)%s*$")
		if not isPrefixExpression(receiver) then
			receiverText = `({receiverText})`
		end

		replacements[call.func] = `{receiverText}:{method}`
		replacements[receiver] = DELETE

		local separator = call.arguments.separators[1]
		if separator then
			replacements[separator] = DELETE
		end
	end

	return replacements
end

local migration: transformTypes.Migration = {
	transform = transform,
}

return table.freeze(migration)

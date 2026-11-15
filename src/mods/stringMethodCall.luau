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
local unwrapGroups = require("../lib/unwrapGroups")

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
	-- throws, and `((5)):rep(3)` throws too. A literal of any other type would
	-- hit the same error.
	if isLiteral(unwrapGroups(receiver)) then
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

local function getPositionKey(location: syntax.Span): string
	return `{location.beginLine}:{location.beginColumn}`
end

-- Finds where each statement that can open with an expression begins, like a
-- bare call or an assignment. A rewrite that would put `(` at one of these
-- positions is skipped. Luau could read that `(` as a call on the end of the
-- line before, as in `local saved = getValue()` followed by
-- `(a .. b):gsub("x", "y")`.
local function getStatementStarts(parseresult: syntax.CstParseResult): { [string]: true }
	local starts: { [string]: true } = {}
	query
		.findAllFromRoot(parseresult, function(node): syntax.CstStat?
			return utils.isStatExpr(node) or utils.isStatAssign(node) or utils.isStatCompoundAssign(node)
		end)
		:forEach(function(statement)
			starts[getPositionKey(statement.location)] = true
		end)
	return starts
end

local function transform(context: transformTypes.Context): syntaxTypes.Replacements
	local replacements: syntaxTypes.Replacements = {}
	local statementStarts = getStatementStarts(context.parseresult)
	local calls = query.findAllFromRoot(context.parseresult, utils.isExprCall).nodes

	-- The query lists each call before the calls inside it. Working backwards
	-- rewrites the inner ones first, so when an outer call prints its receiver,
	-- as in `string.sub(string.upper(name), 1, 1)`, the receiver already reads
	-- `name:upper()`.
	for i = #calls, 1, -1 do
		local call = calls[i]
		local method = getStringMethodName(call)
		if not method or not canRewrite(call) then
			continue
		end

		local receiver = call.arguments[1]
		local receiverText = printer.printNode(receiver, replacements):gsub("^%s+", ""):gsub("%s+$", "")
		if not isPrefixExpression(receiver) then
			receiverText = `({receiverText})`
		end

		if receiverText:sub(1, 1) == "(" and statementStarts[getPositionKey(call.location)] then
			continue
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

-- Edits that the darklua replacement code mods share: deleting statements,
-- printing a node without the whitespace around it, and turning a block into
-- text that can stand in for the statement that held it.
--
-- A code mod returns replacements, a map from a node to the text that takes
-- its place. By default the printer keeps the whitespace and comments around
-- a replaced node. In Lute's CST, a token's trailing trivia runs to the end of
-- its line, and the next line's indentation is leading trivia of the token
-- that starts it.

local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")
local trivia = require("@std/syntax/utils/trivia")
local utils = require("@std/syntax/utils")

local function triviaText(list: { syntax.Trivia }?): string
	local parts = {}
	for _, item in list or {} do
		table.insert(parts, item.text)
	end
	return table.concat(parts)
end

-- Prints `node` with `replacements` applied, minus the whitespace and comments
-- before its first token and after its last.
local function printWithoutTrivia(node: syntax.CstNode, replacements: syntaxTypes.Replacements): string
	local text = printer.printNode(node, replacements)
	local leading = triviaText(trivia.leftmostTrivia(node))
	local trailing = triviaText(trivia.rightmostTrivia(node))
	if leading ~= "" and text:sub(1, #leading) == leading then
		text = text:sub(#leading + 1)
	end
	if trailing ~= "" and text:sub(-#trailing) == trailing then
		text = text:sub(1, -#trailing - 1)
	end
	return text
end

-- Removes a node along with the whitespace and comments around it.
local DELETE: syntaxTypes.Replacement = {
	content = "",
	preserveTrivia = false,
}

-- Walks down the left edge of an expression to the token it opens with.
local function firstExprToken(expr: syntax.CstExpr): syntax.CstToken?
	if expr.tag == "group" then
		return expr.openParens
	elseif expr.tag == "call" then
		return firstExprToken(expr.func)
	elseif expr.tag == "indexname" or expr.tag == "index" then
		return firstExprToken(expr.expression)
	elseif expr.tag == "instantiate" then
		return firstExprToken(expr.expr)
	end
	-- Every other expression that can start a statement is a name.
	return nil
end

-- Only a bare call or an assignment can open with an expression, so only
-- those can open with `(`.
local function firstTokenText(statement: syntax.CstStat): string?
	local token = if statement.tag == "expression"
		then firstExprToken(statement.expression)
		elseif statement.tag == "assign" then firstExprToken(statement.variables[1])
		elseif statement.tag == "compoundassign" then firstExprToken(statement.variable)
		else nil
	return if token then token.text else nil
end

-- Whether `statement` opens with `(`. Luau refuses to parse such a statement
-- right after another one, because the `(` could also be read as a call on
-- the end of the line before.
local function startsWithParen(statement: syntax.CstStat?): boolean
	return statement ~= nil and firstTokenText(statement) == "("
end

-- Deletes the statement at `index` in `block`. When the statement after it
-- opens with `(` and another statement comes before it, a `;` is left in its
-- place, so the two statements around it stay apart. The first statement in
-- a block follows a keyword like `then` or `do`, which Luau doesn't read as
-- something to call, so it needs no `;`.
local function deleteStatement(block: syntax.CstStatBlock, index: number, replacements: syntaxTypes.Replacements)
	local statement = block.statements[index]
	local nextStatement = block.statements[index + 1]
	if index > 1 and startsWithParen(nextStatement) then
		replacements[statement] = { content = ";", preserveTrivia = false }
	else
		replacements[statement] = DELETE
	end
end

-- Whether a statement in `block` declares something scoped to it: a local, a
-- local function, or a type. Moving such a block's statements into the
-- enclosing block would make those names visible after it.
local function declaresNames(block: syntax.CstStatBlock): boolean
	for _, statement in block.statements do
		if
			utils.isStatLocal(statement)
			or utils.isStatConst(statement)
			or utils.isStatLocalFunction(statement)
			or utils.isStatTypeAlias(statement)
			or utils.isStatTypeFunction(statement)
		then
			return true
		end
	end
	return false
end

-- Whether `block` ends in `return`, `break`, or `continue`. Luau only allows
-- those as the last statement of a block, so they can't be moved into the
-- middle of another one.
local function endsBlock(block: syntax.CstStatBlock): boolean
	local last = block.statements[#block.statements]
	return last ~= nil and (utils.isStatReturn(last) or utils.isStatBreak(last) or utils.isStatContinue(last)) ~= nil
end

-- Returns text that runs `block` in place of the statement that held it, or
-- nil when the block is empty. `opener` is the token just before the block,
-- like `then` or `else`, and `closer` the `end` after it. `nextStatement` is
-- the statement that follows the one being replaced, if any.
--
-- The statements are moved into the enclosing block as they are when that's
-- safe. They're wrapped in `do ... end` when the block declares names, which
-- would otherwise outlive it, or ends in `return`, `break`, or `continue`.
-- They're also wrapped when the block's first statement, or the statement
-- after it, opens with `(`, which Luau could read as a call on the line
-- before.
local function blockAsStatement(
	block: syntax.CstStatBlock,
	opener: syntax.CstToken,
	closer: syntax.CstToken,
	nextStatement: syntax.CstStat?,
	replacements: syntaxTypes.Replacements
): string?
	if #block.statements == 0 then
		return nil
	end

	if
		declaresNames(block)
		or endsBlock(block)
		or startsWithParen(block.statements[1])
		or startsWithParen(nextStatement)
	then
		local body = printer.printNode(block, replacements)
		return `do{triviaText(opener.trailingTrivia)}{body}{triviaText(closer.leadingTrivia)}end`
	end
	return printWithoutTrivia(block, replacements)
end

local function positionKey(location: syntax.Span): string
	return `{location.beginLine}:{location.beginColumn}`
end

-- Finds the expressions that sit right after a `-` with no space between, as
-- in `a -b` or `-x`. Writing a negative number there would make `--`, which
-- starts a comment.
local function findTightMinusOperands(parseresult: syntax.CstParseResult): { [string]: true }
	local positions: { [string]: true } = {}
	local function check(operator: syntax.CstToken, operand: syntax.CstExpr)
		if operator.text == "-" and #operator.trailingTrivia == 0 then
			positions[positionKey(operand.location)] = true
		end
	end
	query.findAllFromRoot(parseresult, utils.isExpr):forEach(function(expr)
		if expr.tag == "binary" then
			check(expr.operator, expr.rhsOperand)
		elseif expr.tag == "unary" then
			check(expr.operator, expr.operand)
		end
	end)
	return positions
end

-- Puts a space in front of replacement text for `node` when the text starts
-- with `-` and `node` follows a `-` with no space between.
local function separateMinus(node: syntax.CstExpr, text: string, tightMinusOperands: { [string]: true }): string
	if text:sub(1, 1) == "-" and tightMinusOperands[positionKey(node.location)] then
		return ` {text}`
	end
	return text
end

-- Whether `expr` can take the place of any other expression as it is, without
-- parentheses: a literal, a name, an index, a function, a table, or something
-- already in parentheses. A binary or unary expression, a cast, or an `if`
-- expression could bind differently to the operators around it. A call or
-- `...` could pass along more than one value.
local function isAtom(expr: syntax.CstExpr): boolean
	return expr.tag == "nil"
		or expr.tag == "boolean"
		or expr.tag == "number"
		or expr.tag == "string"
		or expr.tag == "interpolatedstring"
		or expr.tag == "local"
		or expr.tag == "global"
		or expr.tag == "indexname"
		or expr.tag == "index"
		or expr.tag == "function"
		or expr.tag == "table"
		or expr.tag == "group"
		or expr.tag == "instantiate"
end

return table.freeze({
	DELETE = DELETE,
	findTightMinusOperands = findTightMinusOperands,
	separateMinus = separateMinus,
	isAtom = isAtom,
	triviaText = triviaText,
	printWithoutTrivia = printWithoutTrivia,
	startsWithParen = startsWithParen,
	deleteStatement = deleteStatement,
	declaresNames = declaresNames,
	blockAsStatement = blockAsStatement,
})

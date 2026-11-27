local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

local NAME = "high_cyclomatic_complexity"

-- Selene's default. Its own comment says eslint's 20 was too strict for Lua.
-- Selene ships this lint off; Lute has no default-off setting, so it's on here
-- and projects that don't want it can turn it off in their config.
local DEFAULT_MAXIMUM_COMPLEXITY = 40

local countBlock: (block: syntax.CstStatBlock, complexity: number) -> number
local countExpr: (expr: syntax.CstExpr, complexity: number) -> number

--[[
	Counts a call, index, or instance chain such as `a.b(x)[k]:c()`. Each
	argument and bracketed key adds to the count. The base of the chain counts
	only when the chain ends in a call, as Selene does for a function call. For a
	plain variable chain, Selene skips the base, so `(a and b).c` adds nothing.
	The expression a chain link is applied to, or nil when the link isn't part
	of a chain.
]]
local function chainBase(node: syntax.CstExpr): syntax.CstExpr?
	if node.tag == "call" then
		return node.func
	elseif node.tag == "indexname" or node.tag == "index" then
		return node.expression
	elseif node.tag == "instantiate" then
		return node.expr
	end
	return nil
end

local function countChain(expr: syntax.CstExpr, complexity: number): number
	local total = complexity
	local chain: { syntax.CstExpr } = {}
	local node = expr
	while true do
		local base = chainBase(node)
		if base == nil then
			break
		end
		table.insert(chain, node)
		node = base
	end

	if expr.tag == "call" then
		total = countExpr(node, total)
	end

	for _, link in chain do
		if link.tag == "call" then
			for _, argument in link.arguments do
				total = countExpr(argument, total)
			end
		elseif link.tag == "index" then
			total = countExpr(link.index, total)
		end
	end

	return total
end

type ExprItems = { syntax.CstExpr } | syntax.CstPunctuated<syntax.CstExpr>

local function countExprList(exprs: ExprItems, complexity: number): number
	local total = complexity
	for _, expr in exprs do
		total = countExpr(expr, total)
	end
	return total
end

function countExpr(expr: syntax.CstExpr, complexity: number): number
	if expr.tag == "group" then
		return countExpr(expr.expression, complexity)
	elseif expr.tag == "unary" or expr.tag == "cast" then
		return countExpr(expr.operand, complexity)
	elseif expr.tag == "binary" then
		local total = complexity
		if expr.operator.text == "and" or expr.operator.text == "or" then
			total += 1
		end
		total = countExpr(expr.lhsOperand, total)
		return countExpr(expr.rhsOperand, total)
	elseif expr.tag == "call" or expr.tag == "indexname" or expr.tag == "index" or expr.tag == "instantiate" then
		return countChain(expr, complexity)
	elseif expr.tag == "table" then
		local total = complexity
		for _, entry in expr.entries do
			if entry.kind == "general" then
				total = countExpr(entry.key, total)
			end
			total = countExpr(entry.value, total)
		end
		return total
	elseif expr.tag == "interpolatedstring" then
		return countExprList(expr.expressions, complexity)
	elseif expr.tag == "conditional" then
		-- Selene adds one for the `if` expression and one per `elseif`, but only
		-- counts the values of the `elseif` branches. The condition and values of
		-- the `if` and `else` parts are not counted.
		local total = complexity + 1
		for _, branch in expr.elseifs do
			total = countExpr(branch.thenExpr, total + 1)
		end
		return total
	end
	-- Functions are counted on their own, and names and literals add nothing.
	return complexity
end

-- A `while` or `repeat` adds one, and its condition and body count as usual.
local function countConditionalLoop(loop: syntax.CstStatWhile | syntax.CstStatRepeat, complexity: number): number
	local total = countExpr(loop.condition, complexity + 1)
	return countBlock(loop.body, total)
end

local function countStat(stat: syntax.CstStat, complexity: number): number
	if stat.tag == "assign" then
		local total = complexity
		for _, variable in stat.variables do
			total = countChain(variable, total)
		end
		return countExprList(stat.values, total)
	elseif stat.tag == "compoundassign" then
		-- Selene only counts the right-hand side.
		return countExpr(stat.value, complexity)
	elseif stat.tag == "expression" then
		return countExpr(stat.expression, complexity)
	elseif stat.tag == "local" or stat.tag == "const" then
		return countExprList(stat.values, complexity)
	elseif stat.tag == "do" then
		return countBlock(stat.body, complexity)
	elseif stat.tag == "forin" then
		local total = countExprList(stat.values, complexity + 1)
		return countBlock(stat.body, total)
	elseif stat.tag == "for" then
		local total = countExpr(stat.from, complexity + 1)
		total = countExpr(stat.to, total)
		if stat.step then
			total = countExpr(stat.step, total)
		end
		return countBlock(stat.body, total)
	elseif stat.tag == "while" or stat.tag == "repeat" then
		return countConditionalLoop(stat, complexity)
	elseif stat.tag == "conditional" then
		local total = countExpr(stat.condition, complexity + 1)
		total = countBlock(stat.thenBlock, total)
		for _, branch in stat.elseifs do
			total = countExpr(branch.condition, total + 1)
			total = countBlock(branch.thenBlock, total)
		end
		-- Selene does not count the `else` block at all, so it's skipped here too.
		return total
	elseif stat.tag == "return" then
		return countExprList(stat.expressions, complexity)
	end
	-- Function declarations are counted on their own, and the rest add nothing.
	return complexity
end

function countBlock(block: syntax.CstStatBlock, complexity: number): number
	local total = complexity
	for _, stat in block.statements do
		total = countStat(stat, total)
	end
	return total
end

local function maximumComplexity(options: { [string]: unknown }): number
	if
		typeof(options.maximum_complexity) == "number"
		and options.maximum_complexity >= 0
		and options.maximum_complexity == math.floor(options.maximum_complexity)
	then
		return options.maximum_complexity
	end
	return DEFAULT_MAXIMUM_COMPLEXITY
end

local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: types.RuleContext
): { types.LintViolation }
	local maximum = maximumComplexity(context.options)
	local violations: { types.LintViolation } = {}

	-- Every function, named or anonymous, is measured on its own body. Nested
	-- functions are skipped by the outer count, so each one reports separately.
	-- The query can return a function more than once, so each is measured once.
	local measured: { [syntax.CstExprFunction]: true } = {}
	for _, fn in query.findAllFromRoot(cst, utils.isExprFunction).nodes do
		if measured[fn] then
			continue
		end
		measured[fn] = true

		local complexity = countBlock(fn.body, 1)
		if complexity > maximum then
			local location = syntax.span.create({
				beginLine = fn.functionKeyword.location.beginLine,
				beginColumn = fn.functionKeyword.location.beginColumn,
				endLine = fn.closeParens.location.endLine,
				endColumn = fn.closeParens.location.endColumn,
			})
			local violation: types.LintViolation = {
				lintname = NAME,
				location = getReportLocation(cst, location),
				message = `cyclomatic complexity is too high ({complexity} > {maximum})`,
				severity = "warning",
				sourcepath = sourcepath,
			}
			table.insert(violations, violation)
		end
	end

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

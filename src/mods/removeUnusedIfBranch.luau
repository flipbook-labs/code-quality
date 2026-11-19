-- Removes `if` branches that can never run and the conditions that always
-- pass, replacing darklua's `remove_unused_if_branch` rule. A condition counts
-- when it's built from literals and has no side effects, so run
-- `computeExpression` first to fold build checks like
-- `"prod" == "development"` down to `false`.
--
-- For an `if` statement:
--
-- - A branch whose condition is always false is removed.
-- - A branch whose condition is always true becomes the `else`, and every
--   branch after it is removed.
-- - When no branch is left, the block that runs replaces the whole statement,
--   and an `if` with no block left to run is removed.
-- - An empty `else` is removed.
--
-- An `if` expression works the same way. When only one result is left, it
-- replaces the expression, in parentheses unless it's a name, a literal, or
-- something else that reads the same anywhere.
--
-- A condition with side effects stays even when its value is known, so the
-- side effect still happens. Its branch is emptied when the condition is
-- always false, and the branches after it are removed when it's always true.
-- In an `if` expression, an emptied branch's result becomes `nil`. Darklua
-- does the same.
--
-- Darklua always wraps a block that replaces its `if` in `do ... end`. This
-- mod moves the block's statements into the enclosing block instead when
-- that's safe, and only wraps them when the block declares locals or types,
-- ends in `return`, `break`, or `continue`, or opens with `(`, or when the
-- statement after the `if` opens with `(`. Moved statements keep their
-- original indentation, so run a formatter if the output is meant to be read.
-- A branch written `if local x = f() then` is always kept, since its
-- condition declares a local.
--
-- Run it with `lute transform <package>/src/mods/removeUnusedIfBranch.luau <files>`.

local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")
local transformTypes = require("@std/commands/transform/types")
local utils = require("@std/syntax/utils")

local codemodEdits = require("../lib/codemodEdits")
local evaluator = require("../lib/evaluator")

local DELETE = codemodEdits.DELETE

-- One `if` or `elseif` branch of a statement or an expression. `result` is a
-- block for a statement and an expression for an `if` expression.
type Branch = {
	keyword: syntax.CstToken,
	localKeyword: syntax.CstToken?,
	conditionLocal: syntax.CstLocal?,
	equals: syntax.CstToken?,
	condition: syntax.CstExpr,
	thenKeyword: syntax.CstToken,
	result: syntax.CstNode,
}

-- What a branch's condition says about whether it runs: "always", "never", or
-- "maybe". `pure` is whether the condition can be dropped along with the
-- branch, which needs it to have no side effects.
local function classify(branch: Branch): (string, boolean)
	if branch.conditionLocal then
		return "maybe", false
	end
	local truthy = evaluator.isTruthy(evaluator.evaluate(branch.condition))
	local pure = not evaluator.hasSideEffects(branch.condition)
	if truthy == nil then
		return "maybe", pure
	end
	return if truthy then "always" else "never", pure
end

-- Deletes a whole branch: its keyword, condition, `then`, and result.
local function deleteBranch(branch: Branch, replacements: syntaxTypes.Replacements)
	replacements[branch.keyword] = DELETE
	if branch.localKeyword then
		replacements[branch.localKeyword] = DELETE
	end
	if branch.conditionLocal then
		replacements[branch.conditionLocal] = DELETE
	end
	if branch.equals then
		replacements[branch.equals] = DELETE
	end
	replacements[branch.condition] = DELETE
	replacements[branch.thenKeyword] = DELETE
	replacements[branch.result] = DELETE
end

-- Removes the branches before `firstKept`. The first branch's `if` keyword
-- stays, and the rest of the first kept branch follows it.
local function deleteLeadingBranches(branches: { Branch }, firstKept: number, replacements: syntaxTypes.Replacements)
	if firstKept == 1 then
		return
	end
	local ifKeyword = branches[1].keyword
	for index = 1, firstKept - 1 do
		deleteBranch(branches[index], replacements)
	end
	replacements[ifKeyword] = nil
	replacements[branches[firstKept].keyword] = DELETE
end

local function statementBranches(statement: syntax.CstStatIf): { Branch }
	local branches: { Branch } = {
		{
			keyword = statement.ifKeyword,
			localKeyword = statement.localKeyword,
			conditionLocal = statement.conditionLocal,
			equals = statement.equals,
			condition = statement.condition,
			thenKeyword = statement.thenKeyword,
			result = statement.thenBlock,
		},
	}
	for _, branch in statement.elseifs do
		table.insert(branches, {
			keyword = branch.elseIfKeyword,
			localKeyword = branch.localKeyword,
			conditionLocal = branch.conditionLocal,
			equals = branch.equals,
			condition = branch.condition,
			thenKeyword = branch.thenKeyword,
			result = branch.thenBlock,
		})
	end
	return branches
end

local function expressionBranches(expr: syntax.CstExprIfElse): { Branch }
	local branches: { Branch } = {
		{
			keyword = expr.ifKeyword,
			localKeyword = expr.localKeyword,
			conditionLocal = expr.conditionLocal,
			equals = expr.equals,
			condition = expr.condition,
			thenKeyword = expr.thenKeyword,
			result = expr.thenExpr,
		},
	}
	for _, branch in expr.elseifs do
		table.insert(branches, {
			keyword = branch.elseIfKeyword,
			localKeyword = branch.localKeyword,
			conditionLocal = branch.conditionLocal,
			equals = branch.equals,
			condition = branch.condition,
			thenKeyword = branch.thenKeyword,
			result = branch.thenExpr,
		})
	end
	return branches
end

type Placement = { block: syntax.CstStatBlock, index: number }

local function simplifyStatement(
	statement: syntax.CstStatIf,
	placement: Placement,
	replacements: syntaxTypes.Replacements
)
	local branches = statementBranches(statement)
	local elseBlock = statement.elseBlock
	if elseBlock and #elseBlock.statements == 0 then
		elseBlock = nil
	end

	-- `kept[i]` is true for each branch that stays. `alwaysAt` is the branch
	-- that always runs, if one does, and `promoted` its block when the branch
	-- itself goes and its block becomes the `else`.
	local kept: { boolean } = {}
	local firstKept: number? = nil
	local alwaysAt: number? = nil
	local promoted: syntax.CstStatBlock? = nil
	for index, branch in branches do
		if alwaysAt then
			kept[index] = false
			continue
		end

		local runs, pure = classify(branch)
		if runs == "always" then
			alwaysAt = index
			kept[index] = not pure
			if pure then
				promoted = branch.result :: syntax.CstStatBlock
			end
		elseif runs == "never" then
			kept[index] = not pure
			if not pure and #(branch.result :: syntax.CstStatBlock).statements > 0 then
				replacements[branch.result] = DELETE
			end
		else
			kept[index] = true
		end
		if kept[index] and not firstKept then
			firstKept = index
		end
	end

	local hadEmptyElse = statement.elseBlock ~= nil and elseBlock == nil
	local changed = hadEmptyElse or alwaysAt ~= nil or table.find(kept, false) ~= nil
	if not changed then
		return
	end

	-- The loop above is done changing `firstKept`. A local that isn't
	-- assigned again lets the type checker narrow it below.
	local leading = firstKept
	if not leading then
		-- No branch is left, so the block that runs, if any, takes the
		-- statement's place.
		local block, opener = promoted, statement.thenKeyword
		if promoted and alwaysAt then
			opener = branches[alwaysAt].thenKeyword
		elseif elseBlock and statement.elseKeyword then
			block, opener = elseBlock, statement.elseKeyword
		end

		local nextStatement = placement.block.statements[placement.index + 1]
		local text = if block
			then codemodEdits.blockAsStatement(block, opener, statement.endKeyword, nextStatement, replacements)
			else nil
		if text then
			replacements[statement] = text
		else
			codemodEdits.deleteStatement(placement.block, placement.index, replacements)
		end
		return
	end

	for index, branch in branches do
		if not kept[index] then
			deleteBranch(branch, replacements)
		end
	end
	deleteLeadingBranches(branches, leading, replacements)

	if promoted and alwaysAt then
		-- The branch that always runs becomes the `else`. Its keyword turns
		-- into `else`, and its condition and `then` go.
		local branch = branches[alwaysAt]
		replacements[branch.keyword] = {
			content = `{codemodEdits.triviaText(branch.keyword.leadingTrivia)}else`,
			preserveTrivia = false,
		}
		replacements[branch.thenKeyword] = {
			content = codemodEdits.triviaText(branch.thenKeyword.trailingTrivia),
			preserveTrivia = false,
		}
		replacements[branch.result] = nil
	end

	if (alwaysAt or hadEmptyElse) and statement.elseKeyword and statement.elseBlock then
		replacements[statement.elseKeyword] = DELETE
		replacements[statement.elseBlock] = DELETE
	end
end

-- Returns `expr` as text that can replace the `if` expression it came from.
local function asReplacement(expr: syntax.CstExpr, replacements: syntaxTypes.Replacements): string
	local text = codemodEdits.printWithoutTrivia(expr, replacements)
	return if codemodEdits.isAtom(expr) then text else `({text})`
end

local function simplifyExpression(
	expr: syntax.CstExprIfElse,
	replacements: syntaxTypes.Replacements,
	tightMinusOperands: { [string]: true }
)
	local branches = expressionBranches(expr)

	local function replaceWhole(result: syntax.CstExpr)
		local text = asReplacement(result, replacements)
		replacements[expr] = codemodEdits.separateMinus(expr, text, tightMinusOperands)
	end

	-- Leading branches that never run are skipped. The first branch that
	-- might run, or that has to stay for its side effects, leads the new
	-- expression.
	local first = 1
	while true do
		local branch = branches[first]
		if not branch then
			replaceWhole(expr.elseExpr)
			return
		end

		local runs, pure = classify(branch)
		if runs == "maybe" then
			break
		elseif runs == "always" and pure then
			replaceWhole(branch.result :: syntax.CstExpr)
			return
		elseif runs == "always" then
			deleteLeadingBranches(branches, first, replacements)
			for index = first + 1, #branches do
				deleteBranch(branches[index], replacements)
			end
			replacements[expr.elseExpr] = "nil"
			return
		elseif not pure then
			deleteLeadingBranches(branches, first, replacements)
			replacements[branch.result] = "nil"
			return
		end
		first += 1
	end

	deleteLeadingBranches(branches, first, replacements)

	local decided = false
	local newElse: string? = nil
	for index = first + 1, #branches do
		local branch = branches[index]
		if decided then
			deleteBranch(branch, replacements)
			continue
		end

		local runs, pure = classify(branch)
		if runs == "always" then
			decided = true
			if pure then
				newElse = codemodEdits.printWithoutTrivia(branch.result, replacements)
				deleteBranch(branch, replacements)
			end
		elseif runs == "never" then
			if pure then
				deleteBranch(branch, replacements)
			else
				replacements[branch.result] = "nil"
			end
		end
	end

	if decided then
		replacements[expr.elseExpr] = newElse or "nil"
	end
end

local function transform(context: transformTypes.Context): syntaxTypes.Replacements
	local replacements: syntaxTypes.Replacements = {}
	local tightMinusOperands = codemodEdits.findTightMinusOperands(context.parseresult)

	local placements: { [syntax.CstStat]: Placement } = {}
	query.findAllFromRoot(context.parseresult, utils.isStatBlock):forEach(function(block)
		for index, statement in block.statements do
			placements[statement] = { block = block, index = index }
		end
	end)

	-- The query lists each `if` before the ones inside it. Working backwards
	-- simplifies the inner ones first, so an outer `if` that's replaced by one
	-- of its blocks prints that block already simplified.
	local nodes = query.findAllFromRoot(context.parseresult, function(node): (syntax.CstStatIf | syntax.CstExprIfElse)?
		return utils.isStatIf(node) or utils.isExprIfElse(node)
	end).nodes
	for index = #nodes, 1, -1 do
		local node = nodes[index]
		if node.kind == "stat" then
			simplifyStatement(node, placements[node], replacements)
		else
			simplifyExpression(node, replacements, tightMinusOperands)
		end
	end

	return replacements
end

local migration: transformTypes.Migration = {
	transform = transform,
}

return table.freeze(migration)

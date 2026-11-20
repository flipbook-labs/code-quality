-- Removes statements that can never run because a `do ... end` block before
-- them always returns, replacing darklua's `filter_after_early_return` rule.
-- Luau only allows `return` as the last statement of a block, so code that
-- returns early is written `do return end`. `removeUnusedIfBranch` also leaves
-- that shape behind when it turns `if true then return end` into a block.
--
-- As in darklua, only `do` blocks count. A block always returns when its last
-- statement is a `return`. One that ends in some other statement, but not in
-- `break` or `continue`, also counts when it holds a `do` block that always
-- returns. An `if` that returns from every branch doesn't count.
--
-- Run it with `lute transform <package>/src/mods/filterAfterEarlyReturn.luau <files>`.

local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")
local transformTypes = require("@std/commands/transform/types")
local utils = require("@std/syntax/utils")

local codemodEdits = require("../lib/codemodEdits")

-- Returns the position of the first statement in `block` that is a `do` block
-- that always returns.
local function findReturningDo(block: syntax.CstStatBlock): number?
	for index, statement in block.statements do
		local doStatement = utils.isStatDo(statement)
		if not doStatement then
			continue
		end

		local last = doStatement.body.statements[#doStatement.body.statements]
		if last and utils.isStatReturn(last) then
			return index
		elseif last and (utils.isStatBreak(last) or utils.isStatContinue(last)) then
			continue
		elseif findReturningDo(doStatement.body) then
			return index
		end
	end
	return nil
end

local function transform(context: transformTypes.Context): syntaxTypes.Replacements
	local replacements: syntaxTypes.Replacements = {}
	query.findAllFromRoot(context.parseresult, utils.isStatBlock):forEach(function(block)
		local returnsAt = findReturningDo(block)
		if returnsAt then
			for index = returnsAt + 1, #block.statements do
				replacements[block.statements[index]] = codemodEdits.DELETE
			end
		end
	end)
	return replacements
end

local migration: transformTypes.Migration = {
	transform = transform,
}

return table.freeze(migration)

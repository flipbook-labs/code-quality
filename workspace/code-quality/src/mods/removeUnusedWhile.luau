--[[
	Removes `while` loops whose condition is always false, like
	`while false do ... end`, replacing darklua's `remove_unused_while` rule.
	The condition's value must be known and it must have no side effects, the
	same test darklua uses, so the loop never runs and nothing is lost by
	removing it. The mod evaluates conditions itself, so `"prod" == "dev"` and
	`false and f()` both count. Run `injectGlobalValue` first, so build globals
	in conditions have values.

	When the statement after a removed loop opens with `(` and another
	statement comes before the loop, this leaves a `;` in the loop's place, so
	Luau doesn't read that `(` as a call on the line before.

	Run it with `lute transform <package>/src/mods/removeUnusedWhile.luau <files>`.
]]

local query = require("@std/syntax/query")
local syntaxTypes = require("@std/syntax/types")
local transformTypes = require("@std/commands/transform/types")
local utils = require("@std/syntax/utils")

local codemodEdits = require("../lib/codemodEdits")
local evaluator = require("../lib/evaluator")

local function transform(context: transformTypes.Context): syntaxTypes.Replacements
	local replacements: syntaxTypes.Replacements = {}
	query.findAllFromRoot(context.parseresult, utils.isStatBlock):forEach(function(block)
		for index, statement in block.statements do
			local loop = utils.isStatWhile(statement)
			if
				loop
				and not evaluator.hasSideEffects(loop.condition)
				and evaluator.isTruthy(evaluator.evaluate(loop.condition)) == false
			then
				codemodEdits.deleteStatement(block, index, replacements)
			end
		end
	end)
	return replacements
end

local migration: transformTypes.Migration = {
	transform = transform,
}

return table.freeze(migration)

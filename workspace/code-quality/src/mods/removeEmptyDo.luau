--[[
	Removes `do ... end` blocks that contain no statements, replacing darklua's
	`remove_empty_do` rule. A block that holds only empty blocks, like
	`do do end end`, counts as empty too, as does one with only comments in it.
	`removeUnusedIfBranch` can leave such blocks behind, so this runs after it.

	Darklua repeats its pass until nothing changes, which removes nested empty
	blocks the same way. When the statement after a removed block opens with
	`(` and another statement comes before the block, this leaves a `;` in the
	block's place, so Luau doesn't read that `(` as a call on the line before.

	Run it with `lute transform <package>/src/mods/removeEmptyDo.luau <files>`.
]]

local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")
local transformTypes = require("@std/commands/transform/types")
local utils = require("@std/syntax/utils")

local codemodEdits = require("../lib/codemodEdits")

local function isEmptyDo(statement: syntax.CstStat): boolean
	local doStatement = utils.isStatDo(statement)
	if not doStatement then
		return false
	end
	for _, inner in doStatement.body.statements do
		if not isEmptyDo(inner) then
			return false
		end
	end
	return true
end

local function transform(context: transformTypes.Context): syntaxTypes.Replacements
	local replacements: syntaxTypes.Replacements = {}
	query.findAllFromRoot(context.parseresult, utils.isStatBlock):forEach(function(block)
		for index, statement in block.statements do
			if isEmptyDo(statement) then
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

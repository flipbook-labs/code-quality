--[[
	Removes `nil` from local declarations, so `local name = nil` becomes
	`local name`, replacing darklua's `remove_nil_declaration` rule. A local
	starts as `nil` anyway, so the value adds nothing.

	In a declaration with several names, the names that took `nil` move to the
	end, as darklua does: `local a, b = nil, 1` becomes `local b, a = 1`. When
	the last value left is a call or `...`, it gets parentheses, so it still
	sets one name instead of handing its extra values to the names after it.
	Like darklua, this also drops values past the last name that have no side
	effects, as in `local a = 1, 2`.

	A declaration is left alone when moving names could change what it means.
	That's when it has fewer values than names and the last one is a call or
	`...`, which fills the rest, or when it declares the same name twice, where
	the later one wins. Darklua reorders the second case anyway. `const`
	declarations are left alone, as in darklua.

	A declaration that changes is written out again on one line, so comments
	between its names and values are lost. Comments before and after it stay.

	Run it with `lute transform <package>/src/mods/removeNilDeclaration.luau <files>`.
]]

local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")
local transformTypes = require("@std/commands/transform/types")
local utils = require("@std/syntax/utils")

local codemodEdits = require("../lib/codemodEdits")
local evaluator = require("../lib/evaluator")

local function hasDuplicateNames(variables: { syntax.CstLocal }): boolean
	local seen = {}
	for _, variable in variables do
		if seen[variable.name.text] then
			return true
		end
		seen[variable.name.text] = true
	end
	return false
end

local function anyNil(values: { syntax.CstExpr }): boolean
	for _, value in values do
		if utils.isExprConstantNil(value) then
			return true
		end
	end
	return false
end

type Declaration = {
	variables: { syntax.CstLocal },
	values: { syntax.CstExpr },
}

-- Returns the declaration's new names and values, or nil when it stays as it
-- is.
local function simplify(statement: syntax.CstStatLocal): Declaration?
	local variables: { syntax.CstLocal } = {}
	for _, variable in statement.variables do
		table.insert(variables, variable)
	end

	local changed = false
	local values: { syntax.CstExpr } = {}
	for index, value in statement.values do
		if index > #variables and not evaluator.hasSideEffects(value) then
			changed = true
		else
			table.insert(values, value)
		end
	end

	local last = values[#values]
	local canReorder = #values <= #variables
		and anyNil(values)
		and not (#variables > #values and evaluator.canReturnMultipleValues(last))
		and not hasDuplicateNames(variables)
	if not canReorder then
		return if changed then { variables = variables, values = values } else nil
	end

	local keptVariables: { syntax.CstLocal } = {}
	local movedVariables: { syntax.CstLocal } = {}
	local keptValues: { syntax.CstExpr } = {}
	for index, variable in variables do
		local value = values[index]
		if value and utils.isExprConstantNil(value) then
			table.insert(movedVariables, variable)
		else
			table.insert(keptVariables, variable)
			if value then
				table.insert(keptValues, value)
			end
		end
	end
	table.move(movedVariables, 1, #movedVariables, #keptVariables + 1, keptVariables)
	return {
		variables = keptVariables,
		values = keptValues,
	}
end

local function transform(context: transformTypes.Context): syntaxTypes.Replacements
	local replacements: syntaxTypes.Replacements = {}
	query.findAllFromRoot(context.parseresult, utils.isStatLocal):forEach(function(statement)
		local declaration = simplify(statement)
		if not declaration then
			return
		end
		local variables, values = declaration.variables, declaration.values

		local names = {}
		for _, variable in variables do
			table.insert(names, codemodEdits.printWithoutTrivia(variable, replacements))
		end

		local texts = {}
		for index, value in values do
			local text = codemodEdits.printWithoutTrivia(value, replacements)
			if index == #values and #variables > #values and evaluator.canReturnMultipleValues(value) then
				text = `({text})`
			end
			table.insert(texts, text)
		end

		local export = if statement.exportKeyword then "export " else ""
		local assignment = if #texts > 0 then ` = {table.concat(texts, ", ")}` else ""
		replacements[statement] = `{export}local {table.concat(names, ", ")}{assignment}`
	end)
	return replacements
end

local migration: transformTypes.Migration = {
	transform = transform,
}

return table.freeze(migration)

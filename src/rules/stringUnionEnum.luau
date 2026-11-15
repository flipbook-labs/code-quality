local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../types")

local NAME = "string_union_enum"

-- Two literals read fine as a union. From three on, a frozen table of named
-- constants keeps callers from repeating raw strings.
local MIN_MEMBERS = 3

-- The union's members as a set of strings, when every member is a string
-- literal and there are enough of them to flag.
local function getStringLiterals(union: syntax.CstTypeUnion): { [string]: true }?
	if #union.types < MIN_MEMBERS then
		return nil
	end
	local literals: { [string]: true } = {}
	for _, member in union.types do
		local literal = utils.isTypeSingletonString(member)
		if not literal then
			return nil
		end
		literals[literal.value.text] = true
	end
	return literals
end

-- The string values of a frozen table of named constants, as in
-- `table.freeze({ Home = "Home" })`. A name that isn't a valid identifier can
-- be written as a string key, as in `["home-screen"] = "Home"`. A value may
-- carry a singleton cast, as in `Home = "Home" :: "Home"`, which keeps its
-- literal type.
local function getFrozenStringValues(call: syntax.CstExprCall): { [string]: true }?
	local freeze = utils.isExprIndexName(call.func)
	if not freeze or freeze.accessor.text ~= "." or freeze.index.text ~= "freeze" then
		return nil
	end
	local library = utils.isExprGlobal(freeze.expression)
	if not library or library.name.text ~= "table" or #call.arguments ~= 1 then
		return nil
	end
	local constants = utils.isExprTable(call.arguments[1])
	if not constants or #constants.entries == 0 then
		return nil
	end

	local values: { [string]: true } = {}
	for _, entry in constants.entries do
		if entry.kind == "list" or (entry.kind == "general" and not utils.isExprConstantString(entry.key)) then
			return nil
		end
		local value = entry.value
		local cast = utils.isExprTypeAssertion(value)
		if cast then
			value = cast.operand
		end
		local constant = utils.isExprConstantString(value)
		if not constant then
			return nil
		end
		values[constant.value.text] = true
	end
	return values
end

local function isSameSet(a: { [string]: true }, b: { [string]: true }): boolean
	for key in a do
		if not b[key] then
			return false
		end
	end
	for key in b do
		if not a[key] then
			return false
		end
	end
	return true
end

-- A module that already defines the frozen table can still export the union
-- as the type of its values, so a union with a matching table isn't flagged.
local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local frozenTables = query.findAllFromRoot(cst, utils.isExprCall):mapToArray(getFrozenStringValues)

	return query
		.findAllFromRoot(cst, utils.isStatTypeAlias)
		:filter(function(alias)
			local union = utils.isTypeUnion(alias.type)
			if not alias.isExported or union == nil then
				return false
			end
			local literals = getStringLiterals(union)
			if literals == nil then
				return false
			end
			for _, values in frozenTables do
				if isSameSet(literals, values) then
					return false
				end
			end
			return true
		end)
		:mapToArray(function(alias): types.LintViolation?
			return {
				lintname = NAME,
				location = alias.location,
				message = `Define \`{alias.name.text}\`'s values as a frozen table of named constants, and use those instead of the raw strings.`,
				severity = "warning",
				sourcepath = sourcepath,
			}
		end)
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

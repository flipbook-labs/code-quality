local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../../types")

local NAME = "no_alias_local"

-- `props.foo` and `props.foo.bar` read fine at the point of use. Past two
-- fields, whether a local helps is a judgment call, so those aren't flagged.
local MAX_FIELD_DEPTH = 2

type FieldChain = {
	root: syntax.CstLocal,
	-- The fields read off the root, joined with dots, as in `foo.bar`.
	fields: string,
	depth: number,
}

-- Returns the local at the root of `expr` and the fields read off it when
-- `expr` is a chain of field reads such as `props.foo.bar`.
local function getFieldChain(expr: syntax.CstExpr): FieldChain?
	local names: { string } = {}
	local current = expr
	while true do
		local index = utils.isExprIndexName(current)
		if not index then
			break
		end
		if index.accessor.text ~= "." then
			return nil
		end
		table.insert(names, 1, index.index.text)
		current = index.expression
	end

	local root = utils.isExprLocal(current)
	if not root or #names == 0 then
		return nil
	end
	return {
		root = root["local"],
		fields = table.concat(names, "."),
		depth = #names,
	}
end

-- Every function's parameters count, not just the enclosing function's. A
-- closure that copies `props.text` from an outer `props` is still aliasing an
-- argument.
local function collectParameters(cst: syntax.CstStatBlock): { [syntax.CstLocal]: true }
	local parameters: { [syntax.CstLocal]: true } = {}
	query.findAllFromRoot(cst, utils.isExprFunction):forEach(function(func)
		for _, parameter in func.parameters do
			parameters[parameter] = true
		end
	end)
	return parameters
end

type Writes = {
	-- Locals that are assigned to, including parameters.
	locals: { [syntax.CstLocal]: true },
	-- Field chains that are assigned to, keyed by the local at their root.
	fields: { [syntax.CstLocal]: { string } },
}

local function collectWrites(cst: syntax.CstStatBlock): Writes
	local writes: Writes = {
		locals = {},
		fields = {},
	}
	local function markTarget(target: syntax.CstExpr)
		local variable = utils.isExprLocal(target)
		if variable then
			writes.locals[variable["local"]] = true
			return
		end
		local chain = getFieldChain(target)
		if chain then
			local fields = writes.fields[chain.root] or {}
			table.insert(fields, chain.fields)
			writes.fields[chain.root] = fields
		end
	end
	query.findAllFromRoot(cst, utils.isStatAssign):forEach(function(assign)
		for _, variable in assign.variables do
			markTarget(variable)
		end
	end)
	query.findAllFromRoot(cst, utils.isStatCompoundAssign):forEach(function(assign)
		markTarget(assign.variable)
	end)
	return writes
end

-- A local can't simply be swapped for the field it was read from when either
-- one is written somewhere:
--
-- - A local that gets reassigned is a variable seeded from the field.
-- - When the field, a field it sits in, or the parameter itself is assigned,
--   the local may be keeping the earlier value, as in
--   `local old = props.value; props.value = nextValue; return old`.
local function isWritten(variable: syntax.CstLocal, chain: FieldChain, writes: Writes): boolean
	if writes.locals[variable] or writes.locals[chain.root] then
		return true
	end
	for _, written in writes.fields[chain.root] or {} do
		if chain.fields == written or chain.fields:sub(1, #written + 1) == `{written}.` then
			return true
		end
	end
	return false
end

-- Package and module aliases are welcome, even when the package arrives as a
-- parameter, as in `local Fusion = packages.Fusion`. Those names are
-- PascalCase by convention, so a PascalCase local is treated as one.
local function isPackageAlias(variable: syntax.CstLocal): boolean
	return variable.name.text:match("^%u") ~= nil
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local parameters = collectParameters(cst)
	local writes = collectWrites(cst)
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isStatLocal):forEach(function(statement)
		for index, variable in statement.variables do
			local value = statement.values[index]
			local chain = if value then getFieldChain(value) else nil
			if
				chain
				and chain.depth <= MAX_FIELD_DEPTH
				and parameters[chain.root]
				and not isWritten(variable, chain, writes)
				and not isPackageAlias(variable)
			then
				local root = chain.root
				local violation: types.LintViolation = {
					lintname = NAME,
					location = statement.location,
					message = `Read \`{root.name.text}\`'s field where it's used instead of copying it into \`{variable.name.text}\`.`,
					severity = "warning",
					sourcepath = sourcepath,
				}
				table.insert(violations, violation)
			end
		end
	end)

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../types")

local NAME = "no_alias_local"

-- `props.foo` and `props.foo.bar` read fine at the point of use. Past two
-- fields, whether a local helps is a judgment call, so those aren't flagged.
local MAX_FIELD_DEPTH = 2

-- Returns the local at the root of `expr` when `expr` is a short chain of
-- field reads such as `props.foo.bar`.
local function getFieldChainRoot(expr: syntax.CstExpr): syntax.CstLocal?
	local depth = 0
	local current = expr
	while true do
		local index = utils.isExprIndexName(current)
		if not index then
			break
		end
		if index.accessor.text ~= "." then
			return nil
		end
		depth += 1
		current = index.expression
	end

	local root = utils.isExprLocal(current)
	if not root or depth == 0 or depth > MAX_FIELD_DEPTH then
		return nil
	end
	return root["local"]
end

local function collectParameters(cst: syntax.CstStatBlock): { [syntax.CstLocal]: true }
	local parameters: { [syntax.CstLocal]: true } = {}
	query.findAllFromRoot(cst, utils.isExprFunction):forEach(function(func)
		for _, parameter in func.parameters do
			parameters[parameter] = true
		end
	end)
	return parameters
end

-- A local that gets reassigned later is a variable seeded from the field, not
-- a plain alias, so it's left alone.
local function collectReassigned(cst: syntax.CstStatBlock): { [syntax.CstLocal]: true }
	local reassigned: { [syntax.CstLocal]: true } = {}
	local function markTargets(variables: { syntax.CstExpr })
		for _, variable in variables do
			local target = utils.isExprLocal(variable)
			if target then
				reassigned[target["local"]] = true
			end
		end
	end
	query.findAllFromRoot(cst, utils.isStatAssign):forEach(function(assign)
		local variables: { syntax.CstExpr } = {}
		for _, variable in assign.variables do
			table.insert(variables, variable)
		end
		markTargets(variables)
	end)
	query.findAllFromRoot(cst, utils.isStatCompoundAssign):forEach(function(assign)
		markTargets({ assign.variable })
	end)
	return reassigned
end

-- Package and module aliases are welcome, even when the package arrives as a
-- parameter, as in `local Fusion = packages.Fusion`. Those names are
-- PascalCase by convention, so a PascalCase local is treated as one.
local function isPackageAlias(variable: syntax.CstLocal): boolean
	return variable.name.text:match("^%u") ~= nil
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local parameters = collectParameters(cst)
	local reassigned = collectReassigned(cst)
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isStatLocal):forEach(function(statement)
		for index, variable in statement.variables do
			local value = statement.values[index]
			local root = if value then getFieldChainRoot(value) else nil
			if root and parameters[root] and not reassigned[variable] and not isPackageAlias(variable) then
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

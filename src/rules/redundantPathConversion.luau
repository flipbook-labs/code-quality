local path = require("@std/path")
local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../types")
local unwrapGroups = require("../lib/unwrapGroups")

local NAME = "redundant_path_conversion"

-- Lute's path type, `Pathlike`, accepts a string, a `Path`, or `PathData`, so
-- a function that takes one doesn't need its path turned into a string first.
--
-- A lint rule sees syntax, not types, so it can't tell which arguments are
-- `Pathlike`. This lists them by hand from Lute's typedefs. Each function maps
-- to how many of its leading parameters are `Pathlike`. `join` and `resolve`
-- take any number of paths, so they map to `math.huge` and every argument
-- counts.
--
-- The `cwd` option of `process.run` and `process.system` isn't here, even
-- though it holds a path. Lute types it as a string, and its runtime rejects a
-- `Path`.
local PATHLIKE_PARAMETERS: { [string]: { [string]: number } } = {
	["@std/fs"] = {
		copy = 2,
		createDirectory = 1,
		exists = 1,
		link = 2,
		listDirectory = 1,
		metadata = 1,
		move = 2,
		open = 1,
		readFileToString = 1,
		remove = 1,
		removeDirectory = 1,
		symbolicLink = 2,
		type = 1,
		walk = 1,
		watch = 1,
		writeStringToFile = 1,
	},
	["@std/path"] = {
		basename = 1,
		dirname = 1,
		extname = 1,
		format = 1,
		isAbsolute = 1,
		join = math.huge,
		normalize = 1,
		parse = 1,
		relative = 2,
		resolve = math.huge,
	},
}

-- The `@std/path` functions that return a `Path`. The others don't.
local PATH_RETURNING: { [string]: true } = {
	join = true,
	normalize = true,
	parse = true,
	relative = true,
	resolve = true,
}

-- A local that's assigned again after it's declared may no longer hold what it
-- started with, so the rule doesn't trust what its declaration says about it.
local function collectReassignedLocals(cst: syntax.CstStatBlock): { [syntax.CstLocal]: true }
	local reassigned: { [syntax.CstLocal]: true } = {}
	local function markTarget(target: syntax.CstExpr)
		local variable = utils.isExprLocal(target)
		if variable then
			reassigned[variable["local"]] = true
		end
	end
	query.findAllFromRoot(cst, utils.isStatAssign):forEach(function(assign)
		for _, target in assign.variables do
			markTarget(target)
		end
	end)
	query.findAllFromRoot(cst, utils.isStatCompoundAssign):forEach(function(assign)
		markTarget(assign.variable)
	end)
	return reassigned
end

-- Code can bind a module to any name, as in `local pathlib = require("@std/path")`,
-- so calls are matched by the local they go through rather than its name.
-- This maps each local bound to `require("@std/fs")` or `require("@std/path")`
-- to that require string.
local function collectModuleLocals(
	cst: syntax.CstStatBlock,
	reassigned: { [syntax.CstLocal]: true }
): { [syntax.CstLocal]: string }
	local modules: { [syntax.CstLocal]: string } = {}
	query.findAllFromRoot(cst, utils.isStatLocal):forEach(function(statement)
		for index, variable in statement.variables do
			local value = statement.values[index]
			local call = if value then utils.isExprCall(value) else nil
			local func = if call then utils.isExprGlobal(call.func) else nil
			if call and func and func.name.text == "require" and #call.arguments == 1 then
				local argument = utils.isExprConstantString(call.arguments[1])
				if argument and PATHLIKE_PARAMETERS[argument.value.text] and not reassigned[variable] then
					modules[variable] = argument.value.text
				end
			end
		end
	end)
	return modules
end

type ModuleCall = {
	module: string,
	-- The module's local as the source names it, so messages can quote it.
	alias: string,
	name: string,
}

-- Returns the module and function name when `call` reads a function off one
-- of the locals in `modules`, as in `fs.exists(...)`. It doesn't check that
-- the function takes a `Pathlike`.
local function getModuleCall(call: syntax.CstExprCall, modules: { [syntax.CstLocal]: string }): ModuleCall?
	local index = utils.isExprIndexName(call.func)
	if not index or index.accessor.text ~= "." then
		return nil
	end
	local variable = utils.isExprLocal(index.expression)
	local module = if variable then modules[variable["local"]] else nil
	if not variable or not module then
		return nil
	end
	return {
		module = module,
		alias = variable["local"].name.text,
		name = index.index.text,
	}
end

local function isPathCall(expr: syntax.CstExpr, modules: { [syntax.CstLocal]: string }): boolean
	local call = utils.isExprCall(unwrapGroups(expr))
	local moduleCall = if call then getModuleCall(call, modules) else nil
	return moduleCall ~= nil and moduleCall.module == "@std/path" and PATH_RETURNING[moduleCall.name] == true
end

-- Whether `reference` is `Path` read off an `@std/path` local, as in
-- `path.Path`. The prefix is matched by name against the file's `@std/path`
-- locals, since a type's prefix isn't linked to a local in the syntax tree.
local function isModulePathType(reference: syntax.CstTypeReference, modules: { [syntax.CstLocal]: string }): boolean
	if not reference.prefix or reference.name.text ~= "Path" or reference.parameters then
		return false
	end
	for variable, module in modules do
		if module == "@std/path" and variable.name.text == reference.prefix.text then
			return true
		end
	end
	return false
end

-- A bare `Path` could name any type, so it only counts as a path when the file
-- declares it as `@std/path`'s, as in `type Path = path.Path`.
local function hasPathAlias(cst: syntax.CstStatBlock, modules: { [syntax.CstLocal]: string }): boolean
	return #query.findAllFromRoot(cst, utils.isStatTypeAlias):filter(function(alias)
		local reference = utils.isTypeReference(alias.type)
		return alias.name.text == "Path"
			and alias.generics == nil
			and reference ~= nil
			and isModulePathType(reference, modules)
	end).nodes > 0
end

-- Whether `annotation` is `path.Path`, or a bare `Path` when the file aliases
-- it to `path.Path`. An optional `Path?` doesn't count, since it may be `nil`.
local function isPathAnnotation(
	annotation: syntax.CstType?,
	modules: { [syntax.CstLocal]: string },
	bareIsPath: boolean
): boolean
	local reference = if annotation then utils.isTypeReference(annotation) else nil
	if not reference then
		return false
	end
	if reference.prefix == nil then
		return bareIsPath and reference.name.text == "Path" and reference.parameters == nil
	end
	return isModulePathType(reference, modules)
end

-- Collects the locals and parameters that visibly hold a `Path`: those
-- annotated as one, and locals set from an `@std/path` call that returns one.
local function collectPathLocals(
	cst: syntax.CstStatBlock,
	modules: { [syntax.CstLocal]: string },
	reassigned: { [syntax.CstLocal]: true }
): { [syntax.CstLocal]: true }
	local bareIsPath = hasPathAlias(cst, modules)
	local pathLocals: { [syntax.CstLocal]: true } = {}
	query.findAllFromRoot(cst, utils.isStatLocal):forEach(function(statement)
		for index, variable in statement.variables do
			local value = statement.values[index]
			local fromPathCall = value ~= nil and isPathCall(value, modules)
			if
				not reassigned[variable]
				and (fromPathCall or isPathAnnotation(variable.annotation, modules, bareIsPath))
			then
				pathLocals[variable] = true
			end
		end
	end)
	query.findAllFromRoot(cst, utils.isExprFunction):forEach(function(func)
		for _, parameter in func.parameters do
			if not reassigned[parameter] and isPathAnnotation(parameter.annotation, modules, bareIsPath) then
				pathLocals[parameter] = true
			end
		end
	end)
	return pathLocals
end

type Bindings = {
	modules: { [syntax.CstLocal]: string },
	pathLocals: { [syntax.CstLocal]: true },
}

-- Whether the source shows that `expr` is a `Path`. The rule can't see types,
-- and a value that isn't a path, as in `fs.exists(tostring(123))`, needs its
-- `tostring`. So `tostring` is only reported around a value that's visibly a
-- `Path`.
local function isVisiblyPath(expr: syntax.CstExpr, bindings: Bindings): boolean
	local inner = unwrapGroups(expr)
	local variable = utils.isExprLocal(inner)
	if variable then
		return bindings.pathLocals[variable["local"]] == true
	end
	return isPathCall(inner, bindings.modules)
end

-- Returns the wrapper's name, as the source writes it, when `expr` is a
-- conversion the outer call doesn't need: `tostring(x)` around a visible
-- `Path`, or `path.format(x)` around any single argument. `path.format` only accepts a
-- `Pathlike`, so whatever it's given, the outer call accepts too.
local function getConversionName(expr: syntax.CstExpr, bindings: Bindings): string?
	local call = utils.isExprCall(expr)
	if not call or #call.arguments ~= 1 then
		return nil
	end

	local global = utils.isExprGlobal(call.func)
	if global and global.name.text == "tostring" then
		return if isVisiblyPath(call.arguments[1], bindings) then "tostring" else nil
	end

	local moduleCall = getModuleCall(call, bindings.modules)
	if moduleCall and moduleCall.module == "@std/path" and moduleCall.name == "format" then
		return `{moduleCall.alias}.format`
	end

	return nil
end

-- Removing the wrapper can change what the outer call receives. The wrapper
-- passes along one value. Without it, a call or `...` inside the wrapper lands
-- in the outer call directly, and in the last argument it passes along all of
-- its values. If `getPaths` returns two paths, `fs.copy(path.format(getPaths()))`
-- passes only the first, but `fs.copy(getPaths())` passes both. Those still get
-- reported, without a fix.
--
-- A wrapper in parentheses, or before the last argument, is still cut to one
-- value after the fix, so it's safe. So is an `@std/path` call that returns a
-- `Path`, since that's its only return value.
local function canRemoveWrapper(
	call: syntax.CstExprCall,
	position: number,
	conversionCall: syntax.CstExprCall,
	modules: { [syntax.CstLocal]: string }
): boolean
	local argument = call.arguments[position]
	if position < #call.arguments or unwrapGroups(argument) ~= argument then
		return true
	end
	local inner = conversionCall.arguments[1]
	if isPathCall(inner, modules) then
		return true
	end
	return utils.isExprCall(inner) == nil and utils.isExprVarargs(inner) == nil
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local reassigned = collectReassignedLocals(cst)
	local modules = collectModuleLocals(cst, reassigned)
	local bindings: Bindings = {
		modules = modules,
		pathLocals = collectPathLocals(cst, modules, reassigned),
	}
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isExprCall):forEach(function(call)
		local moduleCall = getModuleCall(call, modules)
		local pathlikeCount = if moduleCall then PATHLIKE_PARAMETERS[moduleCall.module][moduleCall.name] else nil
		if not moduleCall or not pathlikeCount then
			return
		end

		for position, argument in call.arguments do
			if position > pathlikeCount then
				break
			end
			local conversion = unwrapGroups(argument)
			local conversionName = getConversionName(conversion, bindings)
			local conversionCall = utils.isExprCall(conversion)
			if conversionName and conversionCall then
				local violation: types.LintViolation = {
					lintname = NAME,
					location = conversionCall.location,
					message = `\`{moduleCall.alias}.{moduleCall.name}\` takes a \`Pathlike\`, which is already a string, \`Path\`, or \`PathData\`, so the \`{conversionName}\` can go.`,
					severity = "warning",
					sourcepath = sourcepath,
					suggestedfix = if canRemoveWrapper(call, position, conversionCall, modules)
						then {
							fix = printer.printNode(conversionCall.arguments[1]),
						}
						else nil,
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

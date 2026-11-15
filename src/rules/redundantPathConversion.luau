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

-- Code can bind a module to any name, as in `local pathlib = require("@std/path")`,
-- so calls are matched by the local they go through rather than its name.
-- This maps each local bound to `require("@std/fs")` or `require("@std/path")`
-- to that require string. A local that's assigned again later may no longer
-- hold the module, so it's left out.
local function collectModuleLocals(cst: syntax.CstStatBlock): { [syntax.CstLocal]: string }
	local reassigned: { [syntax.CstLocal]: true } = {}
	query.findAllFromRoot(cst, utils.isStatAssign):forEach(function(assign)
		for _, target in assign.variables do
			local variable = utils.isExprLocal(target)
			if variable then
				reassigned[variable["local"]] = true
			end
		end
	end)

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

-- Returns the wrapper's name, as the source writes it, when `expr` is a call
-- to `tostring(x)` or `path.format(x)`. The rule can't see what type `x` is, so
-- most single arguments count. A number or boolean literal, as in
-- `tostring(123)`, is the exception. It isn't a `Pathlike`, so that `tostring`
-- is needed.
local function getConversionName(expr: syntax.CstExpr, modules: { [syntax.CstLocal]: string }): string?
	local call = utils.isExprCall(expr)
	if not call or #call.arguments ~= 1 then
		return nil
	end

	local global = utils.isExprGlobal(call.func)
	if global and global.name.text == "tostring" then
		local argument = unwrapGroups(call.arguments[1])
		if utils.isExprConstantNumber(argument) or utils.isExprConstantBool(argument) then
			return nil
		end
		return "tostring"
	end

	local moduleCall = getModuleCall(call, modules)
	if moduleCall and moduleCall.module == "@std/path" and moduleCall.name == "format" then
		return `{moduleCall.alias}.format`
	end

	return nil
end

-- Removing the wrapper can change what the outer call receives. `tostring`
-- passes along one value, but a call or `...` in the last argument passes along
-- all of its values. If `getPaths` returns two paths, `fs.copy(tostring(getPaths()))`
-- passes only the first, but `fs.copy(getPaths())` passes both. Those still get
-- reported, without a fix.
local function canRemoveWrapper(call: syntax.CstExprCall, position: number, conversionCall: syntax.CstExprCall): boolean
	local argument = call.arguments[position]
	if position < #call.arguments or unwrapGroups(argument) ~= argument then
		return true
	end
	local inner = conversionCall.arguments[1]
	return utils.isExprCall(inner) == nil and utils.isExprVarargs(inner) == nil
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local modules = collectModuleLocals(cst)
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
			local conversionName = getConversionName(conversion, modules)
			local conversionCall = utils.isExprCall(conversion)
			if conversionName and conversionCall then
				local violation: types.LintViolation = {
					lintname = NAME,
					location = conversionCall.location,
					message = `\`{moduleCall.alias}.{moduleCall.name}\` takes a \`Pathlike\`, which is already a string, \`Path\`, or \`PathData\`, so the \`{conversionName}\` can go.`,
					severity = "warning",
					sourcepath = sourcepath,
					suggestedfix = if canRemoveWrapper(call, position, conversionCall)
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

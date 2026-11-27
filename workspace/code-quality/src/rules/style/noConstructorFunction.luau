local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

local NAME = "no_constructor_function"

-- Returns the table a function builds when its whole body is one
-- `return { ... }` with nothing else returned.
local function getReturnedTable(func: syntax.CstExprFunction): syntax.CstExprTable?
	if #func.body.statements ~= 1 then
		return nil
	end
	local statement = utils.isStatReturn(func.body.statements[1])
	if statement == nil or statement.expressions[1] == nil or statement.expressions[2] ~= nil then
		return nil
	end
	return utils.isExprTable(statement.expressions[1])
end

-- Looks through what can wrap a call's target without changing which function
-- runs: type arguments as in `box<<number>>(1)`, parentheses, and casts.
local function unwrapCallee(expr: syntax.CstExpr): syntax.CstExpr
	while true do
		local instantiate = utils.isExprInstantiate(expr)
		local group = utils.isExprGroup(expr)
		local cast = utils.isExprTypeAssertion(expr)
		if instantiate then
			expr = instantiate.expr
		elseif group then
			expr = group.expression
		elseif cast then
			expr = cast.operand
		else
			return expr
		end
	end
end

--[[
	Collects the locals the file uses as values rather than only calling them,
	as in `return create`, `{ new = create }`, or `useMemo(create, {})`. A
	function used that way is needed as a function, so writing its table in
	place isn't an option.
]]
local function collectValueUses(cst: syntax.CstStatBlock): { [syntax.CstLocal]: true }
	local callees: { [syntax.CstExprLocal]: true } = {}
	query.findAllFromRoot(cst, utils.isExprCall):forEach(function(call)
		local callee = utils.isExprLocal(unwrapCallee(call.func))
		if callee then
			callees[callee] = true
		end
	end)

	local valueUses: { [syntax.CstLocal]: true } = {}
	query.findAllFromRoot(cst, utils.isExprLocal):forEach(function(reference)
		if not callees[reference] then
			valueUses[reference["local"]] = true
		end
	end)
	return valueUses
end

--[[
	Flags constructor functions: local functions whose whole body returns a
	table, like `local function member(name) return { source = name } end`. A
	function like that only names a shape, and every caller has to look it up
	to see the table it gets back. Writing the table where it's used shows that
	shape in place, and a type can still name it.

	Only functions the file calls and never uses any other way are flagged. A
	function the module exports, passes as a callback, or stores in a table is
	needed as a function. Function expressions that aren't assigned to a local,
	like `useMemo(function() ... end)` or `function M.new()`, aren't checked
	either, since a caller or the module's API decides their shape.
]]
local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local valueUses = collectValueUses(cst)
	local violations: { types.LintViolation } = {}

	local function check(name: syntax.CstLocal, func: syntax.CstExprFunction, location: syntax.Span)
		if valueUses[name] or getReturnedTable(func) == nil then
			return
		end
		local violation: types.LintViolation = {
			lintname = NAME,
			location = getReportLocation(cst, location),
			message = `\`{name.name.text}\` only returns a table. Write the table where it's used, and name its shape with a type if it needs a name.`,
			severity = "warning",
			sourcepath = sourcepath,
		}
		table.insert(violations, violation)
	end

	query.findAllFromRoot(cst, utils.isStatLocalFunction):forEach(function(statement)
		check(statement.name, statement.func, statement.location)
	end)

	query.findAllFromRoot(cst, utils.isStatLocal):forEach(function(statement)
		for index, variable in statement.variables do
			local value = statement.values[index]
			local func = if value then utils.isExprFunction(value) else nil
			if func then
				check(variable, func, statement.location)
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

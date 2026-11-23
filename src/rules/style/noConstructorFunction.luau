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

--[[
	Collects the locals a module returns, as in `return create` or
	`return { create = create }`. Those functions are the module's API. A
	returned call's arguments count too, so `return table.freeze({ create =
	create })` exports `create`.
]]
local function collectExports(cst: syntax.CstStatBlock): { [syntax.CstLocal]: true }
	local exports: { [syntax.CstLocal]: true } = {}
	local last = cst.statements[#cst.statements]
	local statement = if last then utils.isStatReturn(last) else nil
	if statement == nil then
		return exports
	end

	local expressions: { syntax.CstExpr } = {}
	for _, expression in statement.expressions do
		table.insert(expressions, expression)
		local call = utils.isExprCall(expression)
		if call then
			for _, argument in call.arguments do
				table.insert(expressions, argument)
			end
		end
	end

	for _, expression in expressions do
		local exported = utils.isExprLocal(expression)
		if exported then
			exports[exported["local"]] = true
		end
		local exportTable = utils.isExprTable(expression)
		if exportTable then
			for _, entry in exportTable.entries do
				local value = utils.isExprLocal(entry.value)
				if value then
					exports[value["local"]] = true
				end
			end
		end
	end
	return exports
end

--[[
	Flags constructor functions: local functions whose whole body returns a
	table, like `local function member(name) return { source = name } end`. A
	function like that only names a shape, and every caller has to look it up to see the
	table it gets back. Writing the table where it's used shows that shape in
	place, and a type can still name it.

	A function the module returns is its API, so it's left alone. So are
	functions passed as arguments or stored in table fields, since a caller
	such as `useMemo` or a module's `M.new` decides their shape.
]]
local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local exports = collectExports(cst)
	local violations: { types.LintViolation } = {}

	local function check(name: syntax.CstLocal, func: syntax.CstExprFunction, location: syntax.Span)
		if exports[name] or getReturnedTable(func) == nil then
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

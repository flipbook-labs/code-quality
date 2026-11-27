local path = require("@std/path")
local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")
local unwrapGroups = require("../../lib/unwrapGroups")

local NAME = "manual_table_clone"

-- Where a local was declared: the statement and the position of its name in
-- that statement's list, which is also its position in the values.
type Declaration = { statement: syntax.CstStatLocal | syntax.CstStatConst, index: number }

-- `isBare` is true for `for k, v in t`, where `t` is iterated directly rather
-- than through `pairs`, `ipairs`, or `next`.
type LoopSource = { isIpairs: boolean, isBare: boolean, expr: syntax.CstExpr }

-- A loop shaped like a copy: `for k, v in <source> do target[k] = v end`.
type CopyLoop = { source: LoopSource, target: syntax.CstExprLocal }

type Items<T> = { T } | syntax.CstPunctuated<T>

local function firstItem<T>(items: Items<T>): T?
	for _, item in items do
		return item
	end
	return nil
end

local function itemAt<T>(items: Items<T>, index: number): T?
	local position = 0
	for _, item in items do
		position += 1
		if position == index then
			return item
		end
	end
	return nil
end

-- The name of a global, or nil for anything else. A local named `pairs` could
-- skip or change entries, so only the built-in iterators count.
local function globalName(expr: syntax.CstExpr): string?
	local global = utils.isExprGlobal(expr)
	return if global then global.name.text else nil
end

--[[
	The iterable a loop copies from: `pairs(t)`, `ipairs(t)`, `next, t`, or a
	plain `t`. Returns nil for other loop heads, such as `for k, v in a, pairs(b)`.

	Selene also treats a loop over any other call as copying the call's result.
	That call might return an iterator, as `string.gmatch` does, and then
	`table.clone` would throw, so this rule leaves those loops alone.
]]
local function loopSource(values: Items<syntax.CstExpr>): LoopSource?
	if #values == 1 then
		local value = firstItem(values)
		if value == nil then
			return nil
		end

		local call = utils.isExprCall(unwrapGroups(value))
		if call == nil then
			return {
				isIpairs = false,
				isBare = true,
				expr = value,
			}
		end

		local root = globalName(call.func)
		if root ~= "pairs" and root ~= "ipairs" then
			return nil
		end

		-- `pairs` and `ipairs` only count when called as exactly `pairs(t)`.
		local argument = firstItem(call.arguments)
		local plainCall = not call.self and call.openParens ~= nil
		if not plainCall or #call.arguments ~= 1 or argument == nil then
			return nil
		end
		return {
			isIpairs = root == "ipairs",
			isBare = false,
			expr = argument,
		}
	end

	if #values == 2 then
		local first = firstItem(values)
		local second = itemAt(values, 2)
		if first == nil or second == nil or globalName(first) ~= "next" then
			return nil
		end
		return {
			isIpairs = false,
			isBare = false,
			expr = second,
		}
	end

	return nil
end

local function trim(text: string): string
	local leading = text:gsub("^%s+", "")
	local trimmed = leading:gsub("%s+$", "")
	return trimmed
end

-- Whether position A comes before position B.
local function isBefore(lineA: number, columnA: number, lineB: number, columnB: number): boolean
	return lineA < lineB or (lineA == lineB and columnA < columnB)
end

local function isEmptyTable(expr: syntax.CstExpr?): boolean
	if expr == nil then
		return false
	end
	local tbl = utils.isExprTable(expr)
	return tbl ~= nil and #tbl.entries == 0
end

-- Whether the loop body is only `target[key] = value` and the loop head is
-- `pairs`, `ipairs`, `next`, or a bare iterable.
local function copyTarget(loop: syntax.CstStatForIn): CopyLoop?
	local source = loopSource(loop.values)
	if source == nil or #loop.variables ~= 2 then
		return nil
	end

	local keyName = firstItem(loop.variables)
	local valueName = itemAt(loop.variables, 2)
	if keyName == nil or valueName == nil or #loop.body.statements ~= 1 then
		return nil
	end

	local assign = loop.body.statements[1]
	if assign.tag ~= "assign" or #assign.variables ~= 1 or #assign.values ~= 1 then
		return nil
	end

	local target = firstItem(assign.variables)
	local assigned = firstItem(assign.values)
	if target == nil or assigned == nil then
		return nil
	end
	local indexed = utils.isExprIndexExpr(target)
	if indexed == nil then
		return nil
	end

	local targetLocal = utils.isExprLocal(indexed.expression)
	local indexLocal = utils.isExprLocal(indexed.index)
	local valueLocal = utils.isExprLocal(assigned)
	if targetLocal == nil or indexLocal == nil or valueLocal == nil then
		return nil
	end
	if indexLocal.token.text ~= keyName.name.text or valueLocal.token.text ~= valueName.name.text then
		return nil
	end

	return {
		source = source,
		target = targetLocal,
	}
end

-- Whether the value at `index` in a list of assigned values comes from a call.
-- A name past the end of the list takes a value from a trailing call or `...`,
-- as `iter` does in `local key, iter = f()`.
local function isAssignedFromCall(values: Items<syntax.CstExpr>, index: number): boolean
	local value = itemAt(values, index)
	if value ~= nil then
		return utils.isExprCall(unwrapGroups(value)) ~= nil
	end

	local last = itemAt(values, #values)
	return last ~= nil and (utils.isExprCall(last) ~= nil or utils.isExprVarargs(last) ~= nil)
end

-- Locals that a call ever assigns to, in their declaration or later. A call
-- might return an iterator, as `string.gmatch` does, so iterating one of these
-- directly isn't treated as a table copy.
local function findCallAssignedLocals(cst: syntax.CstStatBlock): { [syntax.CstLocal]: true }
	local callAssigned: { [syntax.CstLocal]: true } = {}
	for _, stat in query.findAllFromRoot(cst, utils.isStatLocal).nodes do
		for index, variable in stat.variables do
			if isAssignedFromCall(stat.values, index) then
				callAssigned[variable] = true
			end
		end
	end
	for _, stat in query.findAllFromRoot(cst, utils.isStatAssign).nodes do
		for index, variable in stat.variables do
			local localRef = utils.isExprLocal(variable)
			if localRef and isAssignedFromCall(stat.values, index) then
				callAssigned[localRef["local"]] = true
			end
		end
	end
	return callAssigned
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local callAssigned = findCallAssignedLocals(cst)
	local declarations: { [syntax.CstLocal]: Declaration } = {}
	for _, stat in query.findAllFromRoot(cst, utils.isStatLocal).nodes do
		for index, variable in stat.variables do
			declarations[variable] = { statement = stat, index = index }
		end
	end
	for _, stat in query.findAllFromRoot(cst, utils.isStatConst).nodes do
		for index, variable in stat.variables do
			declarations[variable] = { statement = stat, index = index }
		end
	end

	local blockOf: { [syntax.CstStat]: syntax.CstStatBlock } = {}
	for _, block in query.findAllFromRoot(cst, utils.isStatBlock).nodes do
		for _, statement in block.statements do
			blockOf[statement] = block
		end
	end

	local localRefs = query.findAllFromRoot(cst, utils.isExprLocal).nodes
	local violations: { types.LintViolation } = {}

	for _, loop in query.findAllFromRoot(cst, utils.isStatForIn).nodes do
		local copy = copyTarget(loop)
		if copy == nil then
			continue
		end
		local source = copy.source
		local targetLocal = copy.target

		local sourceLocal = if source.isBare then utils.isExprLocal(unwrapGroups(source.expr)) else nil
		if sourceLocal and callAssigned[sourceLocal["local"]] then
			continue
		end

		local declaration = declarations[targetLocal["local"]]
		if declaration == nil then
			continue
		end
		local declaringStatement = declaration.statement
		local declaredValue = itemAt(declaringStatement.values, declaration.index)
		if not isEmptyTable(declaredValue) then
			continue
		end

		local definitionSpan = declaringStatement.location
		local targetSpan = targetLocal.location

		-- Any use of the target between its definition and the loop may have
		-- filled it in another way, so the copy doesn't apply.
		local usedInBetween = false
		for _, reference in localRefs do
			if
				reference["local"] == targetLocal["local"]
				and isBefore(
					definitionSpan.endLine,
					definitionSpan.endColumn,
					reference.location.endLine,
					reference.location.endColumn
				)
				and isBefore(
					reference.location.beginLine,
					reference.location.beginColumn,
					targetSpan.beginLine,
					targetSpan.beginColumn
				)
			then
				usedInBetween = true
				break
			end
		end
		if usedInBetween then
			continue
		end

		-- Only a copy in the same block as the definition is a candidate, since
		-- the definition has to be in scope and in the same statement list.
		local block = blockOf[declaringStatement]
		if block == nil or block ~= blockOf[loop] then
			continue
		end

		local statementInBetween = false
		for _, statement in block.statements do
			if
				statement ~= loop
				and isBefore(
					definitionSpan.endLine,
					definitionSpan.endColumn,
					statement.location.beginLine,
					statement.location.beginColumn
				)
				and isBefore(
					statement.location.beginLine,
					statement.location.beginColumn,
					loop.location.beginLine,
					loop.location.beginColumn
				)
			then
				statementInBetween = true
				break
			end
		end

		local targetName = targetLocal.token.text
		local sourceText = trim(printer.printNode(source.expr))
		local message =
			`Copying into \`{targetName}\` with a loop is a manual table.clone. \`local {targetName} = table.clone({sourceText})\` does the same.`
		if source.isIpairs then
			message ..= " `ipairs` only copies the array part, so this is only equivalent for tables without keyed fields. Add `-- lute-lint-ignore(manual_table_clone)` if so."
		end

		local location: syntax.Span
		if statementInBetween then
			location = loop.location
			message ..= ` The \`{targetName}\` definition on line {definitionSpan.beginLine} can be removed.`
		else
			location = syntax.span.create({
				beginLine = definitionSpan.beginLine,
				beginColumn = definitionSpan.beginColumn,
				endLine = loop.location.endLine,
				endColumn = loop.location.endColumn,
			})
		end

		local violation: types.LintViolation = {
			lintname = NAME,
			location = getReportLocation(cst, location),
			message = message,
			severity = "warning",
			sourcepath = sourcepath,
		}
		table.insert(violations, violation)
	end

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

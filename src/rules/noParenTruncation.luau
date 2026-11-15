local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../types")
local unwrapGroups = require("../lib/unwrapGroups")

local NAME = "no_paren_truncation"

-- Parentheses around a call keep only its first return value, as in
-- `return (text:gsub("%s", ""))`. That's easy to read as decoration, and
-- removing the parentheses quietly passes the extra values along. A local that
-- captures the first value says the same thing plainly.
--
-- Only the last expression in a list can pass along more than one value: the
-- last argument of a call, the last value returned, the last entry of a table
-- list, or the last value assigned to more variables than there are values.
-- Anywhere else, as in `local value = (f())` or `if (f()) then`, the call is
-- already cut to one value and the parentheses change nothing.
local function collectMultiValueExprs(cst: syntax.CstStatBlock): { [syntax.CstExpr]: true }
	local exprs: { [syntax.CstExpr]: true } = {}
	local function markLast(list: { syntax.CstExpr })
		local last = list[#list]
		if last then
			exprs[last] = true
		end
	end
	local function toList(punctuated: syntax.CstPunctuated<syntax.CstExpr>): { syntax.CstExpr }
		local list: { syntax.CstExpr } = {}
		for _, expr in punctuated do
			table.insert(list, expr)
		end
		return list
	end

	query.findAllFromRoot(cst, utils.isExprCall):forEach(function(call)
		markLast(toList(call.arguments))
	end)
	query.findAllFromRoot(cst, utils.isStatReturn):forEach(function(statement)
		markLast(toList(statement.expressions))
	end)
	query.findAllFromRoot(cst, utils.isExprTable):forEach(function(tbl)
		local last = tbl.entries[#tbl.entries]
		if last and last.kind == "list" then
			exprs[last.value] = true
		end
	end)
	query.findAllFromRoot(cst, utils.isStatLocal):forEach(function(statement)
		if #statement.variables > #statement.values then
			markLast(toList(statement.values))
		end
	end)
	query.findAllFromRoot(cst, utils.isStatAssign):forEach(function(statement)
		if #statement.variables > #statement.values then
			markLast(toList(statement.values))
		end
	end)
	query.findAllFromRoot(cst, utils.isStatForIn):forEach(function(loop)
		markLast(toList(loop.values))
	end)

	return exprs
end

-- `((f()))` truncates just like `(f())`, so nested parentheses are looked
-- through to find the call.
local function wrapsCall(group: syntax.CstExprGroup): boolean
	return utils.isExprCall(unwrapGroups(group.expression)) ~= nil
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local multiValueExprs = collectMultiValueExprs(cst)

	return query
		.findAllFromRoot(cst, utils.isExprGroup)
		:filter(function(group)
			return multiValueExprs[group] == true and wrapsCall(group)
		end)
		:mapToArray(function(group): types.LintViolation?
			return {
				lintname = NAME,
				location = group.location,
				message = "Capture the call's first return value in a local instead of wrapping the call in parentheses.",
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

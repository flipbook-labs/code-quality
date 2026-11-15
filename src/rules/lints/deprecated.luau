local path = require("@std/path")
local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getGlobalNamePath = require("../../lib/globalNamePath")
local getReportLocation = require("../../lib/getReportLocation")
local standardLibrary = require("../../lib/standardLibrary")
local types = require("../../types")

local NAME = "deprecated"

type Pattern = { string }

local function splitPath(dotted: string): { string }
	local words: { string } = {}
	local start = 1
	while true do
		local dot = dotted:find(".", start, true)
		if not dot then
			table.insert(words, dotted:sub(start))
			return words
		end
		table.insert(words, dotted:sub(start, dot - 1))
		start = dot + 1
	end
end

-- Reads the `allow` option, a list of dotted paths. Entries that aren't
-- strings are ignored.
local function readAllow(options: { [string]: unknown }): { Pattern }
	local patterns: { Pattern } = {}
	if typeof(options.allow) ~= "table" then
		return patterns
	end
	for _, entry in options.allow :: { unknown } do
		if typeof(entry) == "string" then
			table.insert(patterns, splitPath(entry))
		end
	end
	return patterns
end

-- A pattern allows the path it names and everything under it, so `table`
-- allows `table.getn`. A `*` word matches any one name, so `table.*` allows
-- `table.getn` and `table.foreach`. As in Selene, a pattern longer than the
-- name never matches it.
local function isAllowed(patterns: { Pattern }, namePath: { string }): boolean
	for _, pattern in patterns do
		if #pattern <= #namePath then
			local matches = true
			for index, word in pattern do
				if word ~= "*" and word ~= namePath[index] then
					matches = false
					break
				end
			end
			if matches then
				return true
			end
		end
	end
	return false
end

-- Fills `%1`, `%2`, and so on with the call's arguments. Returns nil when the
-- template names an argument the call doesn't have, so no suggestion is made.
local function renderReplacement(template: string, values: { string }): string?
	local complete = true
	local rendered = template:gsub("%%(%d+)", function(digits: string): string
		local value = values[tonumber(digits) or 0]
		if value == nil then
			complete = false
			return ""
		end
		return value
	end)
	if complete then
		return rendered
	end
	return nil
end

-- The argument as written in the source, without the whitespace around it.
local function sourceText(expr: syntax.CstExpr): string
	local text = printer.printNode(expr)
	return text:match("^%s*(.-)%s*$") or text
end

local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: types.RuleContext
): { types.LintViolation }
	local allow = readAllow(context.options)
	local violations: { types.LintViolation } = {}

	local function report(location: syntax.Span, message: string)
		local violation: types.LintViolation = {
			lintname = NAME,
			location = getReportLocation(cst, location),
			message = message,
			severity = "warning",
			sourcepath = sourcepath,
		}
		table.insert(violations, violation)
	end

	-- `argumentNodes` is set for a call and nil for a plain reference. Like
	-- Selene, every deprecated prefix of the path is reported, so `a.b.c` gets
	-- a violation for `a.b` and another for `a.b.c` when both are deprecated.
	local function checkNamePath(
		location: syntax.Span,
		kind: string,
		namePath: { string },
		argumentNodes: { syntax.CstExpr }?
	)
		if isAllowed(allow, namePath) then
			return
		end

		local joined = table.concat(namePath, ".")
		local argumentTexts: { string } = {}
		for _, argument in argumentNodes or {} do
			table.insert(argumentTexts, sourceText(argument))
		end

		for count = 1, #namePath do
			local deprecation = standardLibrary.getDeprecation(table.concat(namePath, ".", 1, count))
			if deprecation then
				local message = `Standard library {kind} \`{joined}\` is deprecated: {deprecation.message}`
				local replacement = if deprecation.replace
					then renderReplacement(deprecation.replace, argumentTexts)
					else nil
				if replacement then
					message = message .. ` Try \`{replacement}\`.`
				end
				report(location, message)
			end
		end

		if argumentNodes then
			for index, argument in argumentNodes do
				local parameterMessage = standardLibrary.getDeprecatedParameter(joined, index)
				if parameterMessage and argumentTexts[index] ~= "nil" then
					report(argument.location, `This parameter is deprecated: {parameterMessage}`)
				end
			end
		end
	end

	local calls = query.findAllFromRoot(cst, utils.isExprCall)
	local indexes = query.findAllFromRoot(cst, utils.isExprIndexName)
	local globals = query.findAllFromRoot(cst, utils.isExprGlobal)

	-- A chain such as `a.b.c` or `a.b(x)` is one name, so only its outermost
	-- expression gets checked. Call targets are checked as calls, and assignment
	-- targets are left alone, as Selene does.
	local inChain: { [syntax.CstExpr]: true } = {}
	calls:forEach(function(call)
		inChain[call.func] = true
	end)
	indexes:forEach(function(index)
		inChain[index.expression] = true
	end)
	query.findAllFromRoot(cst, utils.isStatAssign):forEach(function(assign)
		for _, variable in assign.variables do
			inChain[variable] = true
		end
	end)
	query.findAllFromRoot(cst, utils.isStatCompoundAssign):forEach(function(assign)
		inChain[assign.variable] = true
	end)

	calls:forEach(function(call)
		local namePath = getGlobalNamePath(call.func)
		if namePath then
			local arguments: { syntax.CstExpr } = {}
			for _, argument in call.arguments do
				table.insert(arguments, argument)
			end
			checkNamePath(call.location, "function", namePath, arguments)
		end
	end)
	indexes:forEach(function(index)
		if inChain[index] then
			return
		end
		local namePath = getGlobalNamePath(index)
		if namePath then
			checkNamePath(index.location, "expression", namePath, nil)
		end
	end)
	globals:forEach(function(global)
		if inChain[global] then
			return
		end
		checkNamePath(global.location, "expression", { global.name.text }, nil)
	end)

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

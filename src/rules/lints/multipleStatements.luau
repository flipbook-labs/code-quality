local path = require("@std/path")
local syntax = require("@std/syntax")
local visitorLib = require("@std/syntax/visitor")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

local NAME = "multiple_statements"

-- What the `one_line_if` option accepts. Selene's default allows a one-line
-- `if` whose body is only `return`, `break`, or `continue`, as in
-- `if done then return end`.
local ONE_LINE_IF_MODES = table.freeze({ "allow", "deny", "break-return-only" })

local DEFAULT_ONE_LINE_IF = "break-return-only"

local function readOneLineIf(options: { [string]: unknown }): string
	if typeof(options.one_line_if) == "string" and table.find(ONE_LINE_IF_MODES, options.one_line_if) then
		return options.one_line_if
	end
	return DEFAULT_ONE_LINE_IF
end

local function isLastStatement(statement: syntax.CstStat): boolean
	return statement.tag == "return" or statement.tag == "break" or statement.tag == "continue"
end

--[[
	Flags a statement that ends on a line where another statement already
	ended. Statements are visited in source order, outer ones before the ones
	nested inside them, so in `call(function() a() b() end)` the call claims the
	line and `a()` and `b()` are both flagged, as in Selene.
]]
local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: types.RuleContext
): { types.LintViolation }
	local oneLineIf = readOneLineIf(context.options)

	local violations: { types.LintViolation } = {}
	local linesWithStatement: { [number]: true } = {}
	-- Lines holding the `then` of an `if` that may sit on one line. When the
	-- whole `if` ends on that same line, it gives the line up to the
	-- statement inside it.
	local oneLineIfLines: { [number]: true } = {}

	local function allowsOneLine(ifStatement: syntax.CstStatIf): boolean
		if oneLineIf == "deny" then
			return false
		elseif oneLineIf == "break-return-only" then
			return #ifStatement.thenBlock.statements == 1 and isLastStatement(ifStatement.thenBlock.statements[1])
		end
		return true
	end

	local visitor = visitorLib.create()

	function visitor.visitStat(statement: syntax.CstStat): boolean
		if statement.tag == "block" then
			return true
		end

		if statement.tag == "conditional" and allowsOneLine(statement) then
			oneLineIfLines[statement.thenKeyword.location.endLine] = true
		end

		if linesWithStatement[statement.location.endLine] then
			local violation: types.LintViolation = {
				lintname = NAME,
				location = getReportLocation(cst, statement.location),
				message = "Put each statement on its own line.",
				severity = "warning",
				sourcepath = sourcepath,
			}
			table.insert(violations, violation)
		elseif oneLineIfLines[statement.location.endLine] then
			oneLineIfLines[statement.location.endLine] = nil
		else
			linesWithStatement[statement.location.endLine] = true
		end

		return true
	end

	visitorLib.visit(cst, visitor)

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

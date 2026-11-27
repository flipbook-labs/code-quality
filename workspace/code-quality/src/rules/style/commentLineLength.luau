local path = require("@std/path")
local printer = require("@std/syntax/printer")
local syntax = require("@std/syntax")
local visitor = require("@std/syntax/visitor")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

--[==[
	StyLua wraps code at its `column_width`, but it never rewraps a comment, so
	a line of prose can grow as long as its author typed it. This rule flags
	any line of a comment that runs past `column_width`, which defaults to 120
	like StyLua's, when wrapping can fix it. `canWrap` explains which lines it
	can't. That covers `--` comments and every line of a `--[[ ]]` or
	`--[=[ ]=]` block, including Moonwave doc comments. Code and string literals
	are never flagged.

	A line's width is measured the way StyLua measures indentation: a tab
	counts as `indent_width` columns, which defaults to 4 like StyLua's, and
	any other character counts as one. A line exactly `column_width` wide is
	allowed, as it is in StyLua. The width runs from the start of the line, so
	code before a trailing comment counts toward it.

	Lute stores comments as trivia on the token after them, or on the token
	before them when they share its line. A comment after the last statement in
	a file is in the end-of-file token's trivia, which Lute doesn't pass to
	rules, so it isn't checked.
]==]
local NAME = "comment_line_length"
local DEFAULT_COLUMN_WIDTH = 120
local DEFAULT_INDENT_WIDTH = 4

local function positiveInteger(value: unknown, default: number): number
	if typeof(value) == "number" and value >= 1 and value == math.floor(value) then
		return value
	end
	return default
end

local function measureWidth(text: string, indentWidth: number): number
	local _, tabCount = text:gsub("\t", "")
	-- Text that isn't valid UTF-8 falls back to one column per byte.
	local characterCount = utf8.len(text) or #text
	return characterCount + tabCount * (indentWidth - 1)
end

--[[
	Wrapping moves words onto a new line, so it can't shorten a single word
	that's too long to fit on a line by itself, such as a long URL. Flagging
	that line would leave nothing to do but ignore the rule. So a line is only
	flagged when wrapping has a word to move: either the first word to cross
	the limit would fit after the same prefix, or more words follow it. In the
	second case the long word can still leave its line over the limit, but
	once the words after it move, that line has nothing left to wrap and
	stops being flagged.

	`contentStart` is the byte where the comment's text begins on this line.
	Everything before it, such as indentation, code before a trailing comment,
	or a `--` or `--[=[` marker, is the prefix.
]]
local function canWrap(lineText: string, contentStart: number, columnWidth: number, indentWidth: number): boolean
	local prefixWidth = measureWidth(lineText:sub(1, contentStart - 1), indentWidth)
	local content = lineText:sub(contentStart)
	local crossedLimit = false

	for word, wordEnd in content:gmatch("(%S+)()") do
		if crossedLimit then
			return true
		end

		local endWidth = prefixWidth + measureWidth(content:sub(1, (wordEnd :: number) - 1), indentWidth)
		if endWidth > columnWidth then
			if prefixWidth + measureWidth(word, indentWidth) <= columnWidth then
				return true
			end
			crossedLimit = true
		end
	end

	return false
end

local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: types.RuleContext
): { types.LintViolation }
	local columnWidth = positiveInteger(context.options.column_width, DEFAULT_COLUMN_WIDTH)
	local indentWidth = positiveInteger(context.options.indent_width, DEFAULT_INDENT_WIDTH)
	local violations: { types.LintViolation } = {}

	-- Printing the tree gives back the source exactly, so its lines line up
	-- with the line numbers in each comment's location.
	local sourceLines = printer.printNode(cst):split("\n")

	local function checkComment(comment: syntax.SingleLineComment | syntax.MultiLineComment)
		for lineNumber = comment.location.beginLine, comment.location.endLine do
			local fullLine = sourceLines[lineNumber] or ""
			-- On the comment's last line, code can follow a block comment's
			-- closing brackets, and that code isn't part of the comment.
			local lineText = if lineNumber == comment.location.endLine
				then fullLine:sub(1, comment.location.endColumn - 1)
				else fullLine
			lineText = lineText:gsub("%s+$", "")

			local width = measureWidth(lineText, indentWidth)
			if width <= columnWidth then
				continue
			end

			local commentStart: number
			local contentStart: number
			if lineNumber == comment.location.beginLine then
				commentStart = comment.location.beginColumn
				local marker = lineText:match("^%-%-%[=*%[", commentStart) or "--"
				contentStart = lineText:find("%S", commentStart + #marker) or #lineText + 1
			else
				commentStart = lineText:find("%S") or 1
				contentStart = commentStart
			end

			if not canWrap(lineText, contentStart, columnWidth, indentWidth) then
				continue
			end

			local lineLocation = syntax.span.create({
				beginLine = lineNumber,
				beginColumn = commentStart,
				endLine = lineNumber,
				endColumn = #lineText + 1,
			})
			-- A line inside a table type is reported at the whole table type,
			-- which `getReportLocation` explains.
			local violation: types.LintViolation = {
				lintname = NAME,
				location = getReportLocation(cst, lineLocation),
				message = `This comment line is {width} columns wide, so wrap it to fit in {columnWidth}.`,
				severity = "warning",
				sourcepath = sourcepath,
			}
			table.insert(violations, violation)
		end
	end

	local commentVisitor = visitor.create()
	function commentVisitor.visitToken(token: syntax.CstToken): boolean
		for _, triviaList in { token.leadingTrivia, token.trailingTrivia } do
			for _, trivia in triviaList do
				if trivia.tag == "comment" or trivia.tag == "blockcomment" then
					checkComment(trivia)
				end
			end
		end
		return true
	end
	visitor.visitBlock(cst, commentVisitor)

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

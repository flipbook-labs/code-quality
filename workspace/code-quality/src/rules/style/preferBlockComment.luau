local path = require("@std/path")
local syntax = require("@std/syntax")
local visitor = require("@std/syntax/visitor")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

--[=[
	A comment made of `--` lines reads better as one `--[[ ]]` block once it
	grows long, and a block is easier to rewrap. This rule flags a run of `--`
	lines once it has `line_threshold` lines with text in them, which defaults
	to four. A bare `--` between paragraphs doesn't count toward that.

	Lute stores comments as trivia on the token after them. A token's trailing
	trivia stops at the end of its line, so a comment that sits on its own line
	is always in the leading trivia of the next token, along with the rest of
	its run. A comment after the last statement in a file is in the
	end-of-file token's trivia, which Lute doesn't pass to rules, so it isn't
	checked.
]=]
local NAME = "prefer_block_comment"
local DEFAULT_LINE_THRESHOLD = 4

local function lineThreshold(options: { [string]: unknown }): number
	if
		typeof(options.line_threshold) == "number"
		and options.line_threshold >= 1
		and options.line_threshold == math.floor(options.line_threshold)
	then
		return options.line_threshold
	end
	return DEFAULT_LINE_THRESHOLD
end

--[[
	Some `--` lines are read by tools rather than people: `--!strict` and other
	`--!` lines, `---` doc comments, and the comments that turn off a lint or a
	formatter for the next line. These stay as they are, and one inside a run
	splits it in two.
]]
local function isDirective(text: string): boolean
	return text:find("^%-%-[!%-]") ~= nil
		or text:find("^%-%-%s*lute%-lint%-ignore") ~= nil
		or text:find("^%-%-%s*selene:") ~= nil
		or text:find("^%-%-%s*stylua:") ~= nil
end

-- A comment line's text without its `--` marker, the one space after it, or
-- trailing whitespace. Further spaces are kept, since they can indent an
-- example or a list item's second line.
local function commentContent(comment: syntax.SingleLineComment): string
	local content = comment.text:gsub("^%-%-", ""):gsub("^ ", ""):gsub("%s+$", "")
	return content
end

--[=[
	Builds the block comment that replaces a run. Each line is indented one
	level past the run's own indentation, using a tab unless the run is
	indented with spaces. The block's closing `]]` would end the comment early
	if the text already contains one, so the brackets take as many `=` signs
	as they need to differ from anything in the text.
]=]
local function buildBlockComment(lines: { string }, indent: string): string
	local step = if indent:find(" ") then "    " else "\t"
	local body: { string } = {}
	for _, line in lines do
		table.insert(body, if line == "" then "" else indent .. step .. line)
	end

	local text = table.concat(body, "\n")
	local level = ""
	while text:find(`]{level}]`, 1, true) do
		level ..= "="
	end

	return `--[{level}[\n{text}\n{indent}]{level}]`
end

local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: types.RuleContext
): { types.LintViolation }
	local threshold = lineThreshold(context.options)
	local violations: { types.LintViolation } = {}

	local function checkRun(run: { syntax.SingleLineComment }, indent: string)
		local lines: { string } = {}
		local textLineCount = 0
		for _, comment in run do
			local content = commentContent(comment)
			table.insert(lines, content)
			if content ~= "" then
				textLineCount += 1
			end
		end

		if textLineCount < threshold then
			return
		end

		local first = run[1].location
		local last = run[#run].location
		local runLocation = syntax.span.create({
			beginLine = first.beginLine,
			beginColumn = first.beginColumn,
			endLine = last.endLine,
			endColumn = last.endColumn,
		})

		-- A run inside a table type is reported at the whole table type, which
		-- `getReportLocation` explains. The fix still replaces only the run.
		local violation: types.LintViolation = {
			lintname = NAME,
			location = getReportLocation(cst, runLocation),
			message = `This comment has {textLineCount} lines of text, so write it as one \`--[[ ]]\` block.`,
			severity = "warning",
			sourcepath = sourcepath,
			suggestedfix = {
				location = runLocation,
				fix = buildBlockComment(lines, indent),
			},
		}
		table.insert(violations, violation)
	end

	--[[
		A run is a stack of `--` lines on consecutive lines, each one the first
		thing on its line. A blank line, a block comment, a directive, or a
		comment that follows something else on its line ends the run.
	]]
	local commentVisitor = visitor.create()
	function commentVisitor.visitToken(token: syntax.CstToken): boolean
		local run: { syntax.SingleLineComment } = {}
		local runIndent = ""
		-- The whitespace since the last line break. Any other trivia clears it,
		-- so a comment is the first thing on its line only when it starts right
		-- after this whitespace.
		local indent = ""

		local function endRun()
			if #run > 0 then
				checkRun(run, runIndent)
			end
			run = {}
		end

		for _, trivia in token.leadingTrivia do
			if trivia.tag == "whitespace" then
				indent = if trivia.text:find("\n") then trivia.text:match("[^\n]*$") or "" else indent .. trivia.text
				continue
			end

			if trivia.tag == "comment" and not isDirective(trivia.text) then
				local previous = run[#run]
				local isOwnLine = trivia.location.beginColumn == #indent + 1
				if previous and trivia.location.beginLine ~= previous.location.beginLine + 1 then
					endRun()
				end
				if isOwnLine then
					if #run == 0 then
						runIndent = indent
					end
					table.insert(run, trivia)
				else
					endRun()
				end
			else
				endRun()
			end
			indent = ""
		end
		endRun()

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

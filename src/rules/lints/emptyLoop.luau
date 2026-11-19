local path = require("@std/path")
local syntax = require("@std/syntax")
local visitorLib = require("@std/syntax/visitor")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

local NAME = "empty_loop"

type Loop = syntax.CstStatFor | syntax.CstStatForIn | syntax.CstStatWhile | syntax.CstStatRepeat

-- Whether position A (line, column) comes at or before position B.
local function isAtOrBefore(lineA: number, columnA: number, lineB: number, columnB: number): boolean
	return lineA < lineB or (lineA == lineB and columnA <= columnB)
end

-- Whether `comment` sits in the loop's body, between `do` and `end`, or between
-- `repeat` and `until`. Selene counts a comment anywhere in the loop, so a
-- comment in the header, as in `while --[[ready?]] ready do end`, hid an empty
-- body there.
local function isInBody(loop: Loop, comment: syntax.Span): boolean
	local opener = if loop.tag == "repeat" then loop.repeatKeyword else loop.doKeyword
	local closer = if loop.tag == "repeat" then loop.untilKeyword else loop.endKeyword
	return isAtOrBefore(opener.location.endLine, opener.location.endColumn, comment.beginLine, comment.beginColumn)
		and isAtOrBefore(comment.endLine, comment.endColumn, closer.location.beginLine, closer.location.beginColumn)
end

-- Flags a loop with nothing in its body. With the `comments_count` option
-- set, a comment in the body counts as a body, so a loop left empty on purpose
-- can say why.
local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: types.RuleContext
): { types.LintViolation }
	local commentsCount = context.options.comments_count == true

	local emptyLoops: { Loop } = {}
	local comments: { syntax.Span } = {}

	local function checkLoop(loop: Loop): boolean
		if #loop.body.statements == 0 then
			table.insert(emptyLoops, loop)
		end
		return true
	end

	local function collectComments(trivia: { syntax.Trivia })
		for _, item in trivia do
			if item.tag ~= "whitespace" then
				table.insert(comments, item.location)
			end
		end
	end

	local visitor = visitorLib.create()
	visitor.visitStatFor = checkLoop
	visitor.visitStatForIn = checkLoop
	visitor.visitStatWhile = checkLoop
	visitor.visitStatRepeat = checkLoop
	function visitor.visitToken(token: syntax.CstToken): boolean
		if commentsCount then
			collectComments(token.leadingTrivia)
			collectComments(token.trailingTrivia)
		end
		return true
	end
	visitorLib.visit(cst, visitor)

	local violations: { types.LintViolation } = {}
	for _, loop in emptyLoops do
		local hasComment = false
		for _, comment in comments do
			if isInBody(loop, comment) then
				hasComment = true
				break
			end
		end

		if not hasComment then
			local violation: types.LintViolation = {
				lintname = NAME,
				location = getReportLocation(cst, loop.location),
				message = "This loop's body is empty.",
				severity = "warning",
				sourcepath = sourcepath,
			}
			table.insert(violations, violation)
		end
	end

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

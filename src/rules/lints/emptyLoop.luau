local path = require("@std/path")
local syntax = require("@std/syntax")
local visitorLib = require("@std/syntax/visitor")

local types = require("../../types")

local NAME = "empty_loop"

type Loop = syntax.CstStatFor | syntax.CstStatForIn | syntax.CstStatWhile | syntax.CstStatRepeat

-- Flags a loop with nothing in its body. With the `comments_count` option
-- set, a comment inside the loop counts as a body, so a loop left empty on
-- purpose can say why.
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
			if syntax.span.subsumes(loop.location, comment) then
				hasComment = true
				break
			end
		end

		if not hasComment then
			local violation: types.LintViolation = {
				lintname = NAME,
				location = loop.location,
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

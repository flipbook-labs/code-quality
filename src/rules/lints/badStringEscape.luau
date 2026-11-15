local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getReportLocation = require("../../lib/getReportLocation")
local types = require("../../types")

local NAME = "bad_string_escape"

-- The characters that may follow a backslash in a Luau string, besides the
-- quotes, which depend on the string's quote style. The digits, `x`, `u`, and
-- `z` start longer escapes. Luau's parser rejects those when they're
-- malformed or out of range, so a file with one never reaches this rule. A
-- backslash before a line break continues the string onto the next line.
local VALID_ESCAPES = "abfnrtv\\\n\rxuz0123456789"

type Problem = {
	offset: number,
	message: string,
}

local function findProblems(text: string, quoteStyle: string): { Problem }
	local problems: { Problem } = {}
	local index = 1
	while index <= #text do
		local char = text:sub(index, index)
		if char == "\\" then
			local escaped = text:sub(index + 1, index + 1)
			local message: string? = nil
			if escaped == '"' then
				if quoteStyle == "single" then
					message = "Double quotes don't need escaping inside a single-quoted string."
				end
			elseif escaped == "'" then
				if quoteStyle == "double" then
					message = "Single quotes don't need escaping inside a double-quoted string."
				end
			elseif not VALID_ESCAPES:find(escaped, 1, true) then
				message = `\`\\{escaped}\` isn't an escape sequence.`
			end

			if message then
				table.insert(problems, { offset = index - 1, message = message })
			end
			index += 2
		else
			index += 1
		end
	end
	return problems
end

-- The string's text doesn't include its opening quote, so offsets into it
-- start one column after the token. An escaped line break moves later
-- escapes onto the next line.
local function locateEscape(token: syntax.CstToken, offset: number): syntax.Span
	local line = token.location.beginLine
	local column = token.location.beginColumn + 1
	for index = 1, offset do
		if token.text:sub(index, index) == "\n" then
			line += 1
			column = 1
		else
			column += 1
		end
	end

	return syntax.span.create({
		beginLine = line,
		beginColumn = column,
		endLine = line,
		endColumn = column + 2,
	})
end

-- Flags escapes that don't exist, like `"\q"`, and quotes escaped where they
-- don't need to be, like `"\'"`. Luau's parser already rejects malformed
-- escapes such as `"\x1"`, so Selene's checks for those have nothing to do
-- here. Interpolated strings are left alone, as they are in Selene.
local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isExprConstantString):forEach(function(str)
		if str.quoteStyle ~= "single" and str.quoteStyle ~= "double" then
			return
		end

		for _, problem in findProblems(str.value.text, str.quoteStyle) do
			local violation: types.LintViolation = {
				lintname = NAME,
				location = getReportLocation(cst, locateEscape(str.value, problem.offset)),
				message = problem.message,
				severity = "warning",
				sourcepath = sourcepath,
			}
			table.insert(violations, violation)
		end
	end)

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../types")

local NAME = "no_paren_truncation"

-- Parentheses around a call keep only its first return value, as in
-- `(text:gsub("%s", ""))`. That's easy to read as decoration, and removing
-- the parentheses quietly passes the extra values along. A local that captures
-- the first value says the same thing plainly.
local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	return query
		.findAllFromRoot(cst, utils.isExprGroup)
		:filter(function(group)
			return utils.isExprCall(group.expression) ~= nil
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

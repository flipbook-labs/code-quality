local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getGlobalNamePath = require("../../lib/globalNamePath")
local getReportLocation = require("../../lib/getReportLocation")
local standardLibrary = require("../../lib/standardLibrary")
local types = require("../../types")

local NAME = "must_use"

-- Only a call used as a statement discards its result, so only those are
-- checked. The report covers the called name, not the arguments.
local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	return query.findAllFromRoot(cst, utils.isStatExpr):mapToArray(function(statement): types.LintViolation?
		local call = utils.isExprCall(statement.expression)
		if not call then
			return nil
		end

		local namePath = getGlobalNamePath(call.func)
		if not namePath then
			return nil
		end

		local name = table.concat(namePath, ".")
		if not standardLibrary.isMustUse(name) then
			return nil
		end

		return {
			lintname = NAME,
			location = getReportLocation(cst, call.func.location),
			message = `Return value of \`{name}\` must be used.`,
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

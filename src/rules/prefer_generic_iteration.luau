local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../types")

local NAME = "prefer_generic_iteration"

local function getIteratorName(loop: syntax.CstStatForIn): string?
	if #loop.values ~= 1 then
		return nil
	end
	local call = utils.isExprCall(loop.values[1])
	local global = call and utils.isExprGlobal(call.func)
	if not call or not global or #call.arguments ~= 1 then
		return nil
	end
	local name = global.name.text
	return if name == "pairs" or name == "ipairs" then name else nil
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	return query.findAllFromRoot(cst, utils.isStatForIn):mapToArray(function(loop): types.LintViolation?
		local iterator = getIteratorName(loop)
		if not iterator then
			return nil
		end
		return {
			lintname = NAME,
			location = loop.values[1].location,
			message = `Iterate the table directly, \`for k, v in t do\`, instead of calling \`{iterator}\`.`,
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

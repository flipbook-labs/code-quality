local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../../types")
local unwrapGroups = require("../../lib/unwrapGroups")

local NAME = "no_tonumber_cast"

-- `tonumber` returns `nil` when its string isn't a number. A cast like
-- `tonumber(s) :: number` hides that from the type checker, so a string that
-- stops being numeric later fails somewhere far from here. Any cast on the
-- result is flagged, since one that keeps the `nil`, like `:: number?`, adds
-- nothing. A fallback like `tonumber(s) or 0` handles `nil` without a cast, so
-- it isn't flagged.
--
-- The rule reports these without a fix, because only the code around the call
-- knows what should happen when the string isn't a number.
local function isTonumberCast(cast: syntax.CstExprTypeAssertion): boolean
	local call = utils.isExprCall(unwrapGroups(cast.operand))
	local global = if call then utils.isExprGlobal(call.func) else nil
	return global ~= nil and global.name.text == "tonumber"
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}

	query.findAllFromRoot(cst, utils.isExprTypeAssertion):forEach(function(cast)
		if isTonumberCast(cast) then
			local violation: types.LintViolation = {
				lintname = NAME,
				location = cast.location,
				message = "`tonumber` returns `nil` when the string isn't a number, so handle that case instead of casting the result.",
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

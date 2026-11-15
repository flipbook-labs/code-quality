local path = require("@std/path")
local syntax = require("@std/syntax")

local ignorePattern = require("../../lib/ignorePattern")
local scopeTracker = require("../../lib/scopeTracker")
local types = require("../../types")

local NAME = "global_usage"

-- Flags each use of `_G` that doesn't refer to a local or to a name an earlier
-- assignment declared. Selene also flags `shared` when
-- its Roblox standard library is set, and this rule doesn't, because Lute
-- doesn't know which standard library a project uses.
local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: types.RuleContext
): { types.LintViolation }
	-- With no pattern set, every use is flagged. A pattern lets a field of `_G`
	-- be allowed, as in `_G._foo_`, matched against the first field read.
	local pattern = ignorePattern.read(context.options, "ignore_pattern", nil)
	local violations: { types.LintViolation } = {}

	for _, reference in scopeTracker(cst).globals do
		local firstIndex = reference.firstIndex
		local ignored = firstIndex ~= nil and ignorePattern.isIgnored(pattern, firstIndex)
		if reference.name == "_G" and not reference.resolved and not ignored then
			local violation: types.LintViolation = {
				lintname = NAME,
				location = reference.location,
				message = "use of `_G` is not allowed, structure your code in a more idiomatic way",
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

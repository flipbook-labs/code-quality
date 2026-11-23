local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local types = require("../../types")

local NAME = "no_manifest_function"

-- Lute reads a package manifest from `pkg.luau`, and some Lute releases read
-- `loom.config.luau` instead.
local MANIFEST_NAMES: { [string]: true } = {
	["pkg.luau"] = true,
	["loom.config.luau"] = true,
}

--[[
	A Lute package manifest is the file people read to learn what a package
	depends on. A helper that builds its entries, like `member("semver")`,
	hides each entry's real shape behind a call, so this flags every function
	in a manifest. Types, requires, and plain tables are still fine, so a
	workspace member's manifest can `require` the root manifest to read a
	shared version, and a manifest can describe its entries with a type.
]]
local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}
	if sourcepath == nil or not MANIFEST_NAMES[path.basename(sourcepath) or ""] then
		return violations
	end

	-- `local function` and `function` statements hold their body as a function
	-- expression, so this one query finds all three forms.
	query.findAllFromRoot(cst, utils.isExprFunction):forEach(function(func)
		local violation: types.LintViolation = {
			lintname = NAME,
			location = func.location,
			message = "Write this manifest's entries out in full instead of building them with a function.",
			severity = "warning",
			sourcepath = sourcepath,
		}
		table.insert(violations, violation)
	end)

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

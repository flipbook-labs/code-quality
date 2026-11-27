local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local getReportLocation = require("../../lib/getReportLocation")
local similarNodes = require("../../lib/similarNodes")
local types = require("../../types")

local NAME = "if_same_then_else"

-- Whether a block has anything besides a final `return`, `break`, or
-- `continue`. Selene doesn't count that last statement, so a block that only
-- returns is skipped, as an empty one is.
local function hasStatements(block: syntax.CstStatBlock): boolean
	local count = #block.statements
	if count == 0 then
		return false
	end
	local last = block.statements[count]
	if last.tag == "return" or last.tag == "break" or last.tag == "continue" then
		count -= 1
	end
	return count > 0
end

--[[
	Flags a branch of an `if` whose block repeats an earlier branch of the same
	`if`, as Selene does. Empty blocks are skipped, and a repeat is compared
	only against the blocks that were kept, so three identical branches report
	the second and the third against the first.
]]
local function lintIf(stat: syntax.CstStatIf, sourcepath: path.Path?, cst: syntax.CstStatBlock): { types.LintViolation }
	local violations: { types.LintViolation } = {}

	local kept: { syntax.CstStatBlock } = { stat.thenBlock }
	local branches: { syntax.CstStatBlock } = {}
	for _, branch in stat.elseifs do
		table.insert(branches, branch.thenBlock)
	end
	if stat.elseBlock then
		table.insert(branches, stat.elseBlock)
	end

	for _, block in branches do
		if not hasStatements(block) then
			continue
		end

		local match: syntax.CstStatBlock? = nil
		for _, other in kept do
			if similarNodes(other, block) then
				match = other
				break
			end
		end

		if match then
			local violation: types.LintViolation = {
				lintname = NAME,
				location = getReportLocation(cst, block.location),
				message = `This block is the same as the block on line {match.location.beginLine}.`,
				severity = "warning",
				sourcepath = sourcepath,
			}
			table.insert(violations, violation)
		else
			table.insert(kept, block)
		end
	end

	return violations
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { types.LintViolation }
	local violations: { types.LintViolation } = {}
	for _, stat in query.findAllFromRoot(cst, utils.isStatIf).nodes do
		for _, violation in lintIf(stat, sourcepath, cst) do
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

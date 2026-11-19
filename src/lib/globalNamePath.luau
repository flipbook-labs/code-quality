local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

-- Returns the names in a reference to a global read through dot or colon
-- indexes, such as `{ "table", "getn" }` for `table.getn`. Returns nil for
-- anything else: a local at the root, a bracket index, or a call partway down
-- the chain. Explicit type arguments, as in `table.clone<<T>>`, are skipped.
local function getGlobalNamePath(expr: syntax.CstExpr): { string }?
	local names: { string } = {}
	local instantiate = utils.isExprInstantiate(expr)
	local current = if instantiate then instantiate.expr else expr
	while true do
		local index = utils.isExprIndexName(current)
		if not index then
			break
		end
		table.insert(names, 1, index.index.text)
		current = index.expression
	end

	local root = utils.isExprGlobal(current)
	if not root then
		return nil
	end
	table.insert(names, 1, root.name.text)
	return names
end

return getGlobalNamePath

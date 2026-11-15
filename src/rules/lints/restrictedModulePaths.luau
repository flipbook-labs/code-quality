local path = require("@std/path")
local syntax = require("@std/syntax")
local visitorLib = require("@std/syntax/visitor")

local types = require("../../types")

local NAME = "restricted_module_paths"

-- Reads the `restricted_paths` option, a map from a dotted path such as
-- "OldLibrary.Utils.deprecatedFunction" to the message to show for it. Entries
-- that aren't string to string are skipped.
local function readRestrictedPaths(options: { [string]: unknown }): { [string]: string }
	local restricted: { [string]: string } = {}
	if typeof(options.restricted_paths) ~= "table" then
		return restricted
	end

	for key, message in options.restricted_paths :: { [unknown]: unknown } do
		if typeof(key) == "string" and typeof(message) == "string" then
			restricted[key] = message
		end
	end
	return restricted
end

-- Splits an expression into the name it starts from and the suffixes applied
-- to it, in source order. `a.b(x).c` gives `a` and `.b`, `(x)`, `.c`.
local function flatten(expr: syntax.CstExpr): (syntax.CstExpr, { syntax.CstExpr })
	local reversed: { syntax.CstExpr } = {}
	local current = expr
	while true do
		if current.tag == "indexname" or current.tag == "index" then
			table.insert(reversed, current)
			current = current.expression
		elseif current.tag == "call" then
			table.insert(reversed, current)
			current = current.func
		elseif current.tag == "instantiate" then
			table.insert(reversed, current)
			current = current.expr
		else
			break
		end
	end

	local ordered: { syntax.CstExpr } = {}
	for index = #reversed, 1, -1 do
		table.insert(ordered, reversed[index])
	end
	return current, ordered
end

-- Builds the dotted path Selene matches. It reads names up to the first call,
-- since a call's result isn't a module path, and gives up on a bracket index.
-- Returns the path and the first call, if there is one before it stops.
local function pathOf(root: syntax.CstExpr, suffixes: { syntax.CstExpr }): (string?, syntax.CstExprCall?)
	local names: { string } = {}
	if root.tag == "global" then
		table.insert(names, root.name.text)
	elseif root.tag == "local" then
		table.insert(names, root.token.text)
	else
		return nil, nil
	end

	for _, suffix in suffixes do
		if suffix.tag == "indexname" then
			table.insert(names, suffix.index.text)
		elseif suffix.tag == "call" then
			return table.concat(names, "."), suffix
		else
			return nil, nil
		end
	end

	return table.concat(names, "."), nil
end

-- Whether a chain's last suffix is a call. Selene reports a called path only up
-- to its first call, and a plain access over the whole expression.
local function endsInCall(suffixes: { syntax.CstExpr }): boolean
	local last = suffixes[#suffixes]
	return last ~= nil and last.tag == "call"
end

local function lint(
	cst: syntax.CstStatBlock,
	sourcepath: path.Path?,
	context: types.RuleContext
): { types.LintViolation }
	local restricted = readRestrictedPaths(context.options)
	local violations: { types.LintViolation } = {}

	-- Visits the parts of a chain other than its path: call arguments, bracket
	-- indexes, and the start if it's not a name.
	local visitor = visitorLib.create()

	local function visitChildren(root: syntax.CstExpr, suffixes: { syntax.CstExpr })
		for _, suffix in suffixes do
			if suffix.tag == "call" then
				for _, argument in suffix.arguments do
					visitorLib.visitExpression(argument, visitor)
				end
			elseif suffix.tag == "index" then
				visitorLib.visitExpression(suffix.index, visitor)
			end
		end
		if root.tag ~= "global" and root.tag ~= "local" then
			visitorLib.visitExpression(root, visitor)
		end
	end

	local function check(expr: syntax.CstExpr)
		local root, suffixes = flatten(expr)
		local fullPath, firstCall = pathOf(root, suffixes)
		if fullPath and restricted[fullPath] then
			local location = expr.location
			if endsInCall(suffixes) and firstCall then
				location = firstCall.location
			end
			local violation: types.LintViolation = {
				lintname = NAME,
				location = location,
				message = "Module path `" .. fullPath .. "` is restricted. " .. restricted[fullPath],
				severity = "warning",
				sourcepath = sourcepath,
			}
			table.insert(violations, violation)
		end
		visitChildren(root, suffixes)
	end

	-- Selene checks names used as values and called functions, but not the
	-- targets of an assignment or the names in a function declaration.
	visitor.visitExprGlobal = function(node: syntax.CstExprGlobal): boolean
		check(node)
		return false
	end
	visitor.visitExprLocal = function(node: syntax.CstExprLocal): boolean
		check(node)
		return false
	end
	visitor.visitExprIndexName = function(node: syntax.CstExprIndexName): boolean
		check(node)
		return false
	end
	visitor.visitExprIndexExpr = function(node: syntax.CstExprIndexExpr): boolean
		check(node)
		return false
	end
	visitor.visitExprCall = function(node: syntax.CstExprCall): boolean
		check(node)
		return false
	end
	visitor.visitExprInstantiate = function(node: syntax.CstExprInstantiate): boolean
		check(node)
		return false
	end
	visitor.visitStatAssign = function(stat: syntax.CstStatAssign): boolean
		for _, variable in stat.variables do
			local root, suffixes = flatten(variable)
			visitChildren(root, suffixes)
		end
		for _, value in stat.values do
			visitorLib.visitExpression(value, visitor)
		end
		return false
	end
	visitor.visitStatCompoundAssign = function(stat: syntax.CstStatCompoundAssign): boolean
		local root, suffixes = flatten(stat.variable)
		visitChildren(root, suffixes)
		visitorLib.visitExpression(stat.value, visitor)
		return false
	end
	visitor.visitStatFunction = function(stat: syntax.CstStatFunction): boolean
		local root, suffixes = flatten(stat.name)
		visitChildren(root, suffixes)
		visitorLib.visitExpression(stat.func, visitor)
		return false
	end

	visitorLib.visit(cst, visitor)

	return violations
end

local rule: types.LintRule = {
	name = NAME,
	lint = lint,
}

return table.freeze(rule)

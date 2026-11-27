--[[
	Replaces reads of build globals, like `_G.BUILD_CHANNEL`, with their values
	for this build, replacing darklua's `inject_global_value` rule. Flipbook
	builds use it to bake values such as the release channel into the plugin.
	One run sets every global a build needs. Run `computeExpression` and
	`removeUnusedIfBranch` after it to drop the code a value turns off.

	It takes one option, `globals`, a JSON object that maps each global's name
	to its value. A value is JSON `null`, a boolean, a number, or a string, and
	`null` means `nil`. A value can also be an object that reads an
	environment variable: `{ "env": "NAME" }` uses the variable's text as a
	string, and an optional `"value"` beside it is used when the variable
	isn't set.

	For example, this replaces `_G.BUILD_CHANNEL` with the text of the
	`BUILD_CHANNEL` environment variable, or `"dev"` when it isn't set, and
	`_G.__DEV__` with `false`:

	```sh
	lute transform <package>/src/mods/injectGlobalValue.luau dist -- \
		--globals '{"BUILD_CHANNEL":{"env":"BUILD_CHANNEL","value":"dev"},"__DEV__":false}'
	```

	As in darklua, `_G.NAME`, `_G["NAME"]`, and a bare global `NAME` are all
	replaced, unless a local named `_G` or `NAME` hides the global. An
	assignment to the global, like `_G.NAME = value`, stays as it is, and so
	does `_G:NAME()`, which calls a method on `_G` itself. A value used as a
	prefix, as in
	`_G.NAME:lower()`, gets parentheses.

	Darklua configures one global per rule entry and takes the default for a
	missing variable from a separate `default_value` property, where this mod
	uses `value`. Darklua's `env_json`, which reads JSON from a variable, has
	no equivalent here.
]]

local json = require("@std/json")
local process = require("@std/process")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")
local transformTypes = require("@std/commands/transform/types")
local utils = require("@std/syntax/utils")

local codemodEdits = require("../lib/codemodEdits")
local evaluator = require("../lib/evaluator")

type Options = {
	globals: string,
}

-- Each global's value as Luau source, keyed by its name, set once by
-- `initialize`.
local replacementByName: { [string]: string } = {}

local function formatValue(name: string, value: unknown): string
	if value == json.null then
		return "nil"
	elseif typeof(value) == "boolean" then
		return tostring(value)
	elseif typeof(value) == "number" then
		return evaluator.formatNumber(value)
	elseif typeof(value) == "string" then
		return evaluator.quoteString(value)
	end
	error(`{name} must be JSON null, a boolean, a number, a string, or an object with "env"`)
end

local function configure(options: Options)
	local globals: unknown = json.deserialize(options.globals)
	assert(typeof(globals) == "table", "--globals must be a JSON object mapping names to values")

	replacementByName = {}
	for name, value in globals :: { [unknown]: unknown } do
		-- Lute's JSON decoder also tags each object with a key that isn't a
		-- string, so the type check skips it.
		if typeof(name) ~= "string" then
			continue
		end
		if typeof(value) == "table" then
			local spec = value :: { env: unknown, value: unknown }
			assert(typeof(spec.env) == "string" and spec.env ~= "", `{name}: "env" must name an environment variable`)
			local envValue = process.env[spec.env]
			if envValue then
				replacementByName[name] = evaluator.quoteString(envValue)
			elseif spec.value ~= nil then
				replacementByName[name] = formatValue(name, spec.value)
			else
				print(`warning: environment variable {spec.env} isn't set, so {name} becomes nil`)
				replacementByName[name] = "nil"
			end
		else
			replacementByName[name] = formatValue(name, value)
		end
	end
	assert(next(replacementByName) ~= nil, "--globals must name at least one global")
end

local function initialize(context: transformTypes.InitializationContext<Options>)
	configure(context.options)
end

local function isGlobal(expr: syntax.CstExpr, name: string): boolean
	local global = utils.isExprGlobal(expr)
	return global ~= nil and global.name.text == name
end

-- The name of the configured global `expr` reads, in any of the three forms
-- darklua matches, or nil when it reads none of them.
local function readGlobalName(expr: syntax.CstExpr): string?
	local global = utils.isExprGlobal(expr)
	if global then
		return if replacementByName[global.name.text] then global.name.text else nil
	end

	local name: string? = nil
	local indexName = utils.isExprIndexName(expr)
	if indexName and indexName.accessor.text == "." and isGlobal(indexName.expression, "_G") then
		name = indexName.index.text
	end

	local indexExpr = utils.isExprIndexExpr(expr)
	if indexExpr and isGlobal(indexExpr.expression, "_G") then
		local key = utils.isExprConstantString(indexExpr.index)
		if key and key.quoteStyle ~= "interp" then
			name = key.value.text
		end
	end

	return if name and replacementByName[name] then name else nil
end

local function positionKey(location: syntax.Span): string
	return `{location.beginLine}:{location.beginColumn}`
end

local function transform(context: transformTypes.Context<Options>): syntaxTypes.Replacements
	local replacements: syntaxTypes.Replacements = {}
	local operandContexts = codemodEdits.findOperandContexts(context.parseresult)

	-- Assignments write to the global rather than read it, so their targets
	-- stay. Prefixes, like the `x` in `x.y` or `x()`, need parentheses around
	-- a literal.
	local targets: { [syntax.CstExpr]: true } = {}
	local prefixes: { [syntax.CstExpr]: true } = {}
	local statementStarts: { [string]: true } = {}
	query.findAllFromRoot(context.parseresult, utils.isStat):forEach(function(statement)
		if statement.tag == "assign" then
			for _, variable in statement.variables do
				targets[variable] = true
			end
		elseif statement.tag == "compoundassign" then
			targets[statement.variable] = true
		elseif statement.tag == "function" then
			targets[statement.name] = true
		end
		statementStarts[positionKey(statement.location)] = true
	end)
	query.findAllFromRoot(context.parseresult, utils.isExpr):forEach(function(expr)
		if expr.tag == "call" then
			prefixes[expr.func] = true
		elseif expr.tag == "indexname" or expr.tag == "index" then
			prefixes[expr.expression] = true
		elseif expr.tag == "instantiate" then
			prefixes[expr.expr] = true
		end
	end)

	query
		.findAllFromRoot(context.parseresult, utils.isExpr)
		:filter(function(expr)
			return not targets[expr] and readGlobalName(expr) ~= nil
		end)
		:forEach(function(expr)
			local text = replacementByName[readGlobalName(expr) :: string]
			if prefixes[expr] then
				text = `({text})`
				-- A statement that now opens with `(` could be read as a
				-- call on the line before.
				if statementStarts[positionKey(expr.location)] then
					text = `;{text}`
				end
			end
			replacements[expr] = codemodEdits.fitReplacement(expr, text, operandContexts)
		end)

	return replacements
end

local migration: transformTypes.Migration = {
	options = {
		{ kind = "string", name = "globals" },
	},
	initialize = initialize,
	transform = transform,
}

return table.freeze(migration)

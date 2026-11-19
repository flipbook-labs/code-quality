-- Replaces reads of a build global, like `_G.BUILD_CHANNEL`, with its value
-- for this build, replacing darklua's `inject_global_value` rule. Flipbook
-- builds use it to bake values such as the release channel into the plugin.
-- Run it once per global, then run `computeExpression` and
-- `removeUnusedIfBranch` to drop the code a value turns off.
--
-- It takes three options:
--
-- - `identifier`, the global's name. It's required.
-- - `env`, an environment variable to read the value from. Its text becomes a
--   string literal.
-- - `value`, the value as JSON, such as `true`, `12`, or `"prod"`. It's used
--   when `env` isn't given, or names a variable that isn't set. `null` and an
--   empty value mean `nil`.
--
-- For example, this replaces `_G.BUILD_CHANNEL` with the text of the
-- `BUILD_CHANNEL` environment variable:
--
-- ```sh
-- lute transform <package>/src/mods/injectGlobalValue.luau dist -- --identifier BUILD_CHANNEL --env BUILD_CHANNEL
-- ```
--
-- As in darklua, `_G.NAME`, `_G["NAME"]`, and a bare global `NAME` are all
-- replaced, unless a local named `_G` or `NAME` hides the global. An
-- assignment to the global, like `_G.NAME = value`, stays as it is, and so
-- does a method call on `_G`. A value used as a prefix, as in
-- `_G.NAME:lower()`, gets parentheses.
--
-- Darklua takes the default for a missing variable from a separate
-- `default_value` property, where this mod uses `value`. Darklua's `env_json`,
-- which reads JSON from a variable, has no equivalent here.

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
	identifier: string,
	env: string,
	value: string,
}

-- The global's name and its value as Luau source, set once by `initialize`.
local identifier = ""
local replacementText = "nil"

local function parseJsonValue(text: string): string
	local value: unknown = json.deserialize(text)
	if value == json.null then
		return "nil"
	elseif typeof(value) == "boolean" then
		return tostring(value)
	elseif typeof(value) == "number" then
		return evaluator.formatNumber(value)
	elseif typeof(value) == "string" then
		return evaluator.quoteString(value)
	end
	error(`--value must be JSON null, a boolean, a number, or a string, got {text}`)
end

local function configure(options: Options)
	assert(options.identifier ~= "", "--identifier must name a global")
	identifier = options.identifier

	local envValue = if options.env ~= "" then process.env[options.env] else nil
	if envValue then
		replacementText = evaluator.quoteString(envValue)
	elseif options.value ~= "" then
		replacementText = parseJsonValue(options.value)
	else
		if options.env ~= "" then
			print(`warning: environment variable {options.env} isn't set, so {identifier} becomes nil`)
		end
		replacementText = "nil"
	end
end

local function initialize(context: transformTypes.InitializationContext<Options>)
	configure(context.options)
end

local function isGlobal(expr: syntax.CstExpr, name: string): boolean
	local global = utils.isExprGlobal(expr)
	return global ~= nil and global.name.text == name
end

-- Whether `expr` reads the global, in any of the three forms darklua matches.
local function readsGlobal(expr: syntax.CstExpr): boolean
	if isGlobal(expr, identifier) then
		return true
	end

	local indexName = utils.isExprIndexName(expr)
	if indexName then
		return indexName.accessor.text == "."
			and indexName.index.text == identifier
			and isGlobal(indexName.expression, "_G")
	end

	local indexExpr = utils.isExprIndexExpr(expr)
	if indexExpr then
		local key = utils.isExprConstantString(indexExpr.index)
		return key ~= nil
			and key.quoteStyle ~= "interp"
			and key.value.text == identifier
			and isGlobal(indexExpr.expression, "_G")
	end
	return false
end

local function positionKey(location: syntax.Span): string
	return `{location.beginLine}:{location.beginColumn}`
end

local function transform(context: transformTypes.Context<Options>): syntaxTypes.Replacements
	local replacements: syntaxTypes.Replacements = {}
	local tightMinusOperands = codemodEdits.findTightMinusOperands(context.parseresult)

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
			return not targets[expr] and readsGlobal(expr)
		end)
		:forEach(function(expr)
			local text = replacementText
			if prefixes[expr] then
				text = `({text})`
				-- A statement that now opens with `(` could be read as a
				-- call on the line before.
				if statementStarts[positionKey(expr.location)] then
					text = `;{text}`
				end
			end
			replacements[expr] = codemodEdits.separateMinus(expr, text, tightMinusOperands)
		end)

	return replacements
end

local migration: transformTypes.Migration = {
	options = {
		{ kind = "string", name = "identifier" },
		{
			kind = "string",
			name = "env",
			default = "",
		},
		{
			kind = "string",
			name = "value",
			default = "",
		},
	},
	initialize = initialize,
	transform = transform,
}

return table.freeze(migration)

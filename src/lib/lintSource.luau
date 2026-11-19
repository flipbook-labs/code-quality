local parser = require("@std/syntax/parser")

local types = require("../types")

-- Runs one rule over a snippet of Luau source, the way `lute lint` would run
-- it over a file. `options` stands in for the rule's `options` table from a
-- project's `.config.luau`.
local function lintSource(
	rule: types.LintRule,
	source: string,
	options: { [string]: unknown }?
): { types.LintViolation }
	return rule.lint(parser.parseBlock(source), nil, {
		globals = {},
		options = options or {},
	})
end

return lintSource

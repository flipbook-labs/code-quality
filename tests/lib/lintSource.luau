local parser = require("@std/syntax/parser")

local types = require("@repo/src/types")

-- Runs one rule over a snippet of Luau source, the way `lute lint` would run
-- it over a file.
local function lintSource(rule: types.LintRule, source: string): { types.LintViolation }
	return rule.lint(parser.parseBlock(source), nil, {
		globals = {},
		options = {},
	})
end

return lintSource

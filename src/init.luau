local path = require("@std/path")

local rulesPath = require("@self/rulesPath")

local CodeQuality = {
	-- Both rule folders. Lute loads the rules in each subfolder.
	RULES_PATH = rulesPath,
	-- The Selene replacement, which catches likely bugs.
	LINT_RULES_PATH = path.format(path.join(rulesPath, "lints")),
	-- The house-style rules.
	STYLE_RULES_PATH = path.format(path.join(rulesPath, "style")),
}

return table.freeze(CodeQuality)

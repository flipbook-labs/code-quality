local path = require("@std/path")

local Mod = require("@self/Mod")
local Rule = require("@self/Rule")
local build = require("@self/build")
local lint = require("@self/lint")
local rulesPath = require("@self/rulesPath")
local transform = require("@self/transform")

export type Mod = Mod.Mod
export type Rule = Rule.Rule
export type BuildOptions = build.Options
export type LintOptions = lint.Options

local CodeQuality = {
	-- Both rule folders. Lute loads the rules in each subfolder.
	RULES_PATH = rulesPath,
	-- The Selene replacement, which catches likely bugs.
	LINT_RULES_PATH = path.format(path.join(rulesPath, "lints")),
	-- The house-style rules.
	STYLE_RULES_PATH = path.format(path.join(rulesPath, "style")),
	-- The code mods, which `lute transform` runs.
	MODS_PATH = path.format(path.join(path.dirname(rulesPath), "mods")),

	Mod = Mod,
	Rule = Rule,
	transform = transform,
	build = build,
	lint = lint,
}

return table.freeze(CodeQuality)

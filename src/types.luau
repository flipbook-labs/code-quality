-- These mirror the types `lute lint` expects a rule to return. Lute defines
-- them under its own `@lint` alias, but that alias only resolves inside Lute's
-- bundled rules, so a rule loaded from this package can't require it.

local path = require("@std/path")
local syntax = require("@std/syntax")

export type Severity = "error" | "warning" | "info" | "hint"

export type SuggestedFix = {
	-- Without a location, the fix replaces the violation's whole location.
	location: syntax.Span?,
	fix: string,
}

export type LintViolation = {
	lintname: string,
	location: syntax.Span,
	message: string,
	severity: Severity,
	sourcepath: path.Path?,
	suggestedfix: SuggestedFix?,
}

export type RuleContext = {
	globals: { [string]: unknown },
	options: { [string]: unknown },
}

export type LintRule = {
	read name: string,
	read lint: (cst: syntax.CstStatBlock, sourcepath: path.Path?, context: RuleContext) -> { LintViolation },
}

return nil

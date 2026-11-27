return {
	categories = { "Features", "Fixes", "Changes", "Internal" },
	collapsed = { "Internal" },
	version = {
		current = "0.9.0",
		mirror = {
			{ file = "workspace/code-quality/pkg.luau" },
			{ file = "README.md", pattern = 'rev = "v([%d%.]+)"' },
			{ file = "README.md", pattern = "@lpm/code%-quality@v([%d%.]+)" },
		},
	},
	kind = {
		release = { text = "Release", color = "#94606f" },
		ci = { text = "CI", color = "#75659a" },
		docs = { text = "Docs", color = "#8a5a2b" },
		mods = { text = "Code mods", color = "#8250df" },
		packaging = { text = "Packaging", color = "#7a7444" },
		rules = { text = "Lint rules", color = "#0969da" },
		tooling = { text = "Tooling", color = "#4e8079" },
	},
}

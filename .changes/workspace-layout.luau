return {
	bump = "minor",
	category = "Changes",
	kind = "packaging",
	flags = { "Breaking" },
	summary = 'The package now lives in `workspace/code-quality`, so dependencies on it need `target = "workspace/code-quality"`.',
}

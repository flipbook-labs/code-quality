-- The root has no name or version, which makes it a virtual package. Loom
-- won't install it as a dependency. Instead, each path dependency below is a
-- workspace member: a package in its own `workspace/<folder>` with its own
-- `pkg.luau`. Repos depend on a member through a GitHub dependency whose
-- `target` is that folder, such as `workspace/code-quality`.
local function member(name: string)
	return { sourceKind = "path", source = `./workspace/{name}` }
end

return {
	package = {
		dependencies = {
			["code-quality"] = member("code-quality"),
		},
	},
}

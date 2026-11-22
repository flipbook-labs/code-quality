# Contributing

Install the toolchain with [Rokit](https://github.com/rojo-rbx/rokit), then fetch the Lute typedefs:

```sh
rokit install
lute setup
```

The repository is a Lute package workspace. The root `pkg.luau` has no name or version, which makes it a virtual package, and lists each package under `workspace/` as a member. The CodeQuality package is the `workspace/code-quality` member, and the paths below are relative to that folder. The Lute scripts in `.lute/` stay at the root and work across every member.

Run the checks:

```sh
lute run lint
lute run analyze
lute test
```

`lute run lint` checks formatting with StyLua, lints with Selene, and runs these rules over the package's own source. `lute run analyze` type-checks the source with luau-lsp in strict mode.

Every pull request adds a change entry in `.changes/`, which [Changewrite](https://github.com/flipbook-labs/changewrite) turns into the changelog and the next version. [`.changes/README.md`](.changes/README.md) explains the format.

A daily workflow reruns `lute run generate-roblox-api` and opens a PR when a new Studio build changes the Roblox APIs that `deprecated` flags. Run the script by hand to refresh `src/generated/robloxApiData.luau` sooner.

Each rule lives in `src/rules/lints` or `src/rules/style` with a spec beside it that runs the rule over snippets of source. `lute lint --rules` loads every file in the folder it's given, including the files in its subfolders, and skips the ones that don't return a rule, so the specs ship with the rules and load in any repo that runs them. Keep their requires relative, since a repo alias like `@repo` won't resolve there. Shared helpers go in `src/lib`.

## Adding a rule

1. Add `src/rules/lints/<ruleName>.luau` for a lint that catches likely bugs, or `src/rules/style/<ruleName>.luau` for house style. It returns a frozen `types.LintRule` from `src/types.luau`: a `name` in snake case and a `lint` function that takes the parsed file and returns its violations. Find nodes with `@std/syntax/query` and match them with the `is*` helpers in `@std/syntax/utils`, as the existing rules do. Write against the typedefs for the pinned Lute version in `~/.lute/typedefs`.
2. Add `<ruleName>.spec.luau` beside it. Run snippets through `src/lib/lintSource.luau` and assert on the violations. Cover the code the rule flags and the nearby code it leaves alone.
3. If the rule reports inside a table type, report at `getReportLocation`'s location instead, and add a case to `src/lib/getReportLocation.lute.spec.luau`. Its comment explains why.
4. Add a row to its folder's table in the README, and a change entry in `.changes/`.

## Adding a code mod

A code mod follows the same pattern in `src/mods`. It returns a frozen table with a `transform` function, which takes the file's parse result and returns replacements for the nodes it rewrites. Its spec runs snippets through `src/lib/transformSource.luau` and compares the rewritten source. A mod can also declare `options`, which `lute transform` reads from the arguments after `--`, and an `initialize` function that runs once before the first file. `transformSource` takes the options and the file's path as extra arguments and runs `initialize` the same way. When a mod fixes what a rule flags, share the matching code through `src/lib`, as `stringMethodCall` does with `getStringMethodName`.

# CodeQuality

CodeQuality holds the Luau lint rules, house-style rules, and code mods that flipbook-labs repos share, so every repo enforces them the same way. The house style is written as prose in [agent-skills](https://github.com/flipbook-labs/agent-skills). This package covers the parts a tool can check.

Built for flipbook-labs repos.

## Install

Add CodeQuality to `pkg.luau` as a dev dependency:

```luau
dev_dependencies = {
	["code-quality"] = {
		rev = "v0.7.0",
		sourceKind = "github",
		source = "https://github.com/flipbook-labs/code-quality",
	},
},
```

Then run `lute pkg install --vendor`. That copies CodeQuality into a `.lpm` folder, and scripts require it from there.

## Use

Lint a repo from a Lute script, such as `.lute/lint.luau`, and run it with `lute run lint`:

```luau
local CodeQuality = require("@lpm/code-quality@v0.7.0")

CodeQuality.lint({ "src", ".lute" })
```

`CodeQuality.lint` runs `lute lint` with the rules over the paths, prints each finding, and errors when there is one.

## Rules

The rules come in two folders:

- `src/rules/lints` catches likely bugs, as a replacement for [Selene](https://github.com/Kampfkarren/selene). Each rule is named after the Selene lint it ports and matches its behavior, except for the cases in [Differences from Selene](#differences-from-selene).
- `src/rules/style` enforces the house style.

`CodeQuality.lint` runs both folders by default. Its `rules` option takes a folder instead: `CodeQuality.LINT_RULES_PATH` for only the Selene replacement, or `CodeQuality.STYLE_RULES_PATH` for only the style rules. Set `blocking = false` to print findings as warnings instead of erroring:

```luau
-- Only the Selene replacement, with findings printed as warnings.
CodeQuality.lint({ "src" }, { rules = CodeQuality.LINT_RULES_PATH, blocking = false })
```

`CodeQuality.lint` also errors when `lute lint` itself fails, such as when a rule throws. Lute's built-in rules run alongside these.

To call `lute lint` yourself, pass one folder to `--rules`.

### Lints

| Rule                                    | What it flags                                                                                                                                                                                                                                                                           |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bad_string_escape`                     | An escape that doesn't exist, like `"\q"`, or a quote escaped where it doesn't need to be                                                                                                                                                                                               |
| `compare_nan`                           | `x == 0/0`, which is always false; use `x ~= x`                                                                                                                                                                                                                                         |
| `deprecated`                            | Deprecated standard library functions and fields, such as `table.getn`; deprecated Roblox APIs on `game`, `plugin`, `script`, `workspace`, and `Enum`, such as `workspace:FindPartOnRay` and `Enum.Axis.Left`; and deprecated parameters, such as the second argument to `Instance.new` |
| `empty_loop`                            | A loop with an empty body                                                                                                                                                                                                                                                               |
| `global_usage`                          | Any use of `_G` that isn't a local                                                                                                                                                                                                                                                      |
| `high_cyclomatic_complexity`            | A function with more branches, loops, `and`s, and `or`s than `maximum_complexity` allows                                                                                                                                                                                                |
| `if_same_then_else`                     | An `if` branch whose block repeats an earlier branch of the same `if`                                                                                                                                                                                                                   |
| `ifs_same_cond`                         | An `elseif` whose condition repeats an earlier condition of the same `if`                                                                                                                                                                                                               |
| `manual_table_clone`                    | A loop that copies a fresh table's entries one by one, where `table.clone` does the same                                                                                                                                                                                                |
| `mixed_table`                           | A table constructor with both positional and keyed entries                                                                                                                                                                                                                              |
| `multiple_statements`                   | More than one statement on a line                                                                                                                                                                                                                                                       |
| `must_use`                              | A standard library call whose return value is discarded, as in a `math.max(x, y)` statement                                                                                                                                                                                             |
| `restricted_module_paths`               | A module path listed in the `restricted_paths` option                                                                                                                                                                                                                                   |
| `roblox_incorrect_color3_new_bounds`    | `Color3.new` with a number outside 0 to 1, as in `Color3.new(255, 0, 0)`; use `Color3.fromRGB`                                                                                                                                                                                          |
| `roblox_manual_fromscale_or_fromoffset` | A `UDim2.new` that sets only scale or only offset, which `UDim2.fromScale` or `UDim2.fromOffset` says more plainly                                                                                                                                                                      |
| `roblox_suspicious_udim2_new`           | A `UDim2.new` call with one to three arguments, when it takes four                                                                                                                                                                                                                      |
| `shadowing`                             | A local that redeclares a name already in scope                                                                                                                                                                                                                                         |
| `suspicious_reverse_loop`               | `for i = #t, 1 do`, which needs a step of `-1` to count down                                                                                                                                                                                                                            |
| `unbalanced_assignments`                | An assignment with more values than names, or fewer values without a trailing call                                                                                                                                                                                                      |
| `unscoped_variables`                    | An assignment to a name no local declares, which makes a global                                                                                                                                                                                                                         |

Set a rule's options under `lute.lint.ruleconfigs` in `.config.luau`:

```luau
return {
	lute = {
		lint = {
			ruleconfigs = {
				empty_loop = { options = { comments_count = true } },
			},
		},
	},
}
```

Options for the lints that take them:

- `empty_loop` takes `comments_count`. When it's `true`, a loop whose body is only a comment isn't flagged.
- `multiple_statements` takes `one_line_if`: `"break-return-only"` (the default) allows `if x then return end` on one line, `"allow"` allows any one-line `if` with a single statement, and `"deny"` allows none.
- `high_cyclomatic_complexity` takes `maximum_complexity`, which defaults to `40`.
- `deprecated` takes `allow`, a list of dotted paths to leave alone, such as `table.getn` or `table.*`. A path also allows everything under it. Write a method call with a dot, as in `workspace.FindPartOnRay`.
- `shadowing` and `unscoped_variables` take `ignore_pattern`, which defaults to `"^_"`. `global_usage` also takes `ignore_pattern`, but it has no default, so every use of `_G` is flagged until a pattern is set. A pattern such as `"^_.*_$"` allows a field like `_G._foo_`.
- `restricted_module_paths` takes `restricted_paths`, a map from a dotted path such as `"OldLibrary.Utils.deprecatedFunction"` to the message to show for it. It flags nothing until that map is set.

The Roblox APIs that `deprecated` knows about come from Roblox's API dump for the current Studio build, with messages from Roblox's creator docs.

### Differences from Selene

The lints follow Selene 0.31.0. This section lists every place they don't, so a project moving off Selene knows which results to expect to change.

These apply to every rule:

- Every rule reports at warning severity. Selene reports `compare_nan`, `if_same_then_else`, `ifs_same_cond`, `restricted_module_paths`, `roblox_incorrect_color3_new_bounds`, and `suspicious_reverse_loop` as errors. To match it, set `severity = "error"` in the rule's entry under `ruleconfigs`.
- `high_cyclomatic_complexity` is on by default. Selene ships it off, but Lute has no way to ship a rule off. Set `off = true` in its entry under `ruleconfigs` to turn it off.
- `-- selene: allow(...)` comments are ignored. Use `-- lute-lint-ignore(<rule>)` on the line above the statement.
- Options go in `.config.luau`, not `selene.toml`, and there is no `std` setting. The Roblox lints run in every project, where Selene runs them only when `std` includes `roblox`.
- `ignore_pattern` options take a Lua pattern, not a regular expression. The `"^_"` default behaves the same, but a pattern copied from `selene.toml` may not.

These apply to one rule or a group of them:

| Rule                                                                                                         | Difference                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bad_string_escape`                                                                                          | A malformed or out-of-range escape, like `"\x1"` or `"\u{110000}"`, is a Luau parse error, so the file fails to lint instead of getting this warning.                                                                                                                                                                                                                                                                                                                                  |
| `deprecated`, `must_use`                                                                                     | The standard library lists are hand copies of Selene 0.31.0's `lua51`, `luau`, and `roblox_base` definitions, so they change only when someone updates them. Only globals read through `.` or `:`, like `table.getn`, are checked. Instance methods such as `signal:connect` need the receiver's type and aren't checked.                                                                                                                                                              |
| `deprecated`                                                                                                 | Roblox APIs follow the API dump as of the last `lute run generate-roblox-api`, not the dump Selene's std was generated from. Messages come from Roblox's creator-docs reference rather than Selene's generic "this property is deprecated." Selene flags only an enum item's legacy names, like `Enum.Axis.Left`. This rule also flags items Roblox tags as deprecated, like `Enum.SortOrder.Custom`, and flags a deprecated enum, like `Enum.Status`, once rather than once per item. |
| `must_use`                                                                                                   | A call on a local, like `math.max(x, y)` after `local math = {}`, isn't flagged. Selene flags it.                                                                                                                                                                                                                                                                                                                                                                                      |
| `empty_loop`                                                                                                 | `comments_count` counts only a comment inside the loop's body. Selene counts one anywhere in the loop, so `while --[[ready?]] ready do end` passed there.                                                                                                                                                                                                                                                                                                                              |
| `global_usage`                                                                                               | Only `_G` is flagged. Selene also flags `shared` under its Roblox std.                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `if_same_then_else`, `ifs_same_cond`                                                                         | Two names spelled the same but bound differently, such as a local in one branch and a global in another, compare as different. Selene compares them as the same.                                                                                                                                                                                                                                                                                                                       |
| `manual_table_clone`                                                                                         | The table being copied must be `pairs(t)`, `ipairs(t)`, `next, t`, or a plain `t`. Selene also flags a loop over any other call, as in `for k, v in string.gmatch(text, p) do`, and suggests a `table.clone` that would throw. A local named `pairs`, `ipairs`, or `next`, or a loop over a local set from a call, isn't flagged either.                                                                                                                                               |
| `roblox_incorrect_color3_new_bounds`, `roblox_manual_fromscale_or_fromoffset`, `roblox_suspicious_udim2_new` | Only the globals `Color3` and `UDim2` match. Selene matches the name, so it also flags a local named `Color3`. Argument values are compared as 64-bit floats, not 32-bit, so a value like `1.00000001` that rounds to a bound in 32 bits can disagree.                                                                                                                                                                                                                                 |
| `roblox_suspicious_udim2_new`                                                                                | A call whose last argument is an unparenthesized call or `...`, as in `UDim2.new(parts())`, isn't flagged, since that argument can supply the remaining values. Selene flags it.                                                                                                                                                                                                                                                                                                       |
| `suspicious_reverse_loop`                                                                                    | A hexadecimal end value, as in `for i = #t, 0x10 do`, isn't flagged. Selene flags it.                                                                                                                                                                                                                                                                                                                                                                                                  |
| `unscoped_variables`                                                                                         | An assignment to a standard library global with fields, such as `string = ...`, is flagged. Selene skips it.                                                                                                                                                                                                                                                                                                                                                                           |

Some Selene behavior looks like a bug but is kept, so the same code gets the same result:

- `unbalanced_assignments` treats `(f())` as a call that can fill the remaining names, though the parentheses keep only its first value.
- `multiple_statements` flags the statements inside a one-line function passed as an argument.
- `high_cyclomatic_complexity` doesn't count `else` blocks or the parts of an `if` expression, and treats `t[f()]` as having no side effects.

These Selene lints have no rule here:

- `almost_swapped`, `constant_table_comparison`, `divide_by_zero`, `duplicate_keys`, and `unused_variable` are built into Lute under the same names, as are `empty_if` (as `empty_if_block`) and `parenthese_conditions` (as `parenthesized_conditions`).
- `undefined_variable`, `mismatched_arg_count`, `standard_library`, and `type_check_inside_call` are reported by `luau-lsp analyze` in strict mode.
- `roblox_incorrect_roact_usage` needs Roblox class and property data from Selene's API dump. [#31](https://github.com/flipbook-labs/code-quality/issues/31) tracks porting it.

### Style

| Rule                        | What it asks for                                                                                   |
| --------------------------- | -------------------------------------------------------------------------------------------------- |
| `annotate_nil_local`        | An annotation on locals that start as `nil`                                                        |
| `explicit_instantiation`    | `useState<<string?>>(nil)` instead of casting a literal argument, as in `useState(nil :: string?)` |
| `function_type_param_names` | Named parameters in function types: `(storyModule: ModuleScript) -> ()`                            |
| `inline_table`              | One entry per line once a table or table type has more than three entries, or any returned table   |
| `no_alias_local`            | Reading `props.foo` where it's used instead of copying it into `local foo`                         |
| `no_any`                    | `unknown` instead of `any`                                                                         |
| `no_error_field`            | Error fields named `err` or `problem`, not `error`                                                 |
| `no_paren_truncation`       | A local that captures a call's first return value instead of `(f())`                               |
| `no_tonumber_cast`          | A `nil` check on `tonumber`'s result instead of a cast like `tonumber(s) :: number`                |
| `prefer_annotation`         | `local items: { Item } = {}` instead of `local items = {} :: { Item }`                             |
| `prefer_block_comment`      | One `--[[ ]]` block instead of a run of four or more `--` lines                                    |
| `prefer_generic_iteration`  | `for k, v in t` instead of `pairs(t)` or `ipairs(t)`                                               |
| `redundant_path_conversion` | `fs.exists(file)` instead of `fs.exists(tostring(file))` when `file` is visibly a `Path`           |
| `string_method_call`        | `value:find(...)` instead of `string.find(value, ...)`                                             |
| `string_union_enum`         | A frozen table of named constants alongside an exported union of three or more string literals     |
| `tostring_in_interpolation` | `` `got {value}` `` instead of `` `got {tostring(value)}` ``                                       |

Casting a table to `{ unknown }` or `{ any }`, as React dependency arrays often do, widens it rather than setting a type parameter, so `explicit_instantiation` allows it. `explicit_instantiation` also flags a cast on the result of a call whose only argument is a table constructor. It asks for `table.freeze<<Metrics>>({ ... })` instead of `table.freeze({ ... }) :: Metrics`. It needs StyLua's `syntax = "Luau"` setting, since StyLua can't parse `f<<T>>()` without it.

`no_any`, `prefer_block_comment`, `redundant_path_conversion`, and `tostring_in_interpolation` come with fixes that `lute lint --auto-fix` applies.

`prefer_block_comment` counts only lines with text, so a bare `--` between paragraphs doesn't count. Its `line_threshold` option sets how many lines of text flag a run, and defaults to `4`. Directives stay as `--` lines and split a run: `--!` lines, `---` doc comments, and `lute-lint-ignore`, `selene:`, and `stylua:` comments. A comment after a file's last statement isn't checked, since Lute doesn't pass it to rules.

A Lute script can name a rule with `CodeQuality.Rule`, such as `CodeQuality.Rule.NoAny` for `no_any`.

`redundant_path_conversion` checks the paths passed to `@std/fs` and `@std/path` functions, matched through whatever local `require` binds them to. It flags `path.format` around any value, but `tostring` only around a value the source shows is a `Path`: an `@std/path` call that returns one, a local or parameter annotated `path.Path` (or a bare `Path` when the file declares `type Path = path.Path`), or a local set from such a call and never reassigned. A `tostring` around anything else, like `fs.exists(tostring(123))`, may be needed, so it's left alone. The `cwd` option of `process.run` only accepts a string, so it's left alone too.

## Code mods

A code mod rewrites source in place, for a one-time migration or a fix too large for a lint autofix. Mods live in `src/mods` and run under `lute transform`.

| Mod                      | What it does                                                                |
| ------------------------ | --------------------------------------------------------------------------- |
| `stringMethodCall`       | Rewrites `string.find(value, ...)` as `value:find(...)`                     |
| `convertRequire`         | Rewrites `require("@pkg/React")` as `require(script.Parent.Packages.React)` |
| `injectGlobalValue`      | Replaces a build global like `_G.BUILD_CHANNEL` with its value              |
| `computeExpression`      | Folds expressions built from literals, like `2 * 60 * 1000`                 |
| `removeUnusedIfBranch`   | Removes `if` branches that never run and conditions that always pass        |
| `removeUnusedWhile`      | Removes `while` loops whose condition is always false                       |
| `filterAfterEarlyReturn` | Removes statements after a `do return end`                                  |
| `removeNilDeclaration`   | Turns `local name = nil` into `local name`                                  |
| `removeEmptyDo`          | Removes empty `do ... end` blocks                                           |

All but `stringMethodCall` replace a step of a [darklua](https://github.com/seaofvoices/darklua) build. [Building without darklua](#building-without-darklua) covers them.

`stringMethodCall` fixes what `string_method_call` flags. It leaves a few calls alone because rewriting them could change what the code does: a first argument that can't be a string, like `-5` or `a + b`, a call or `...` passed as the only argument, which may hand over several values, a call with a comment beside its first argument or inside `string.<method>`, and a rewrite that would start a statement with `(`, which Luau could read as a call on the line before. The rule still flags those, so lint afterwards to find any that need a hand edit.

### Running a code mod

From a Lute script that requires CodeQuality as in [Use](#use), `CodeQuality.transform` runs one mod over a list of files and folders. `CodeQuality.Mod` names each mod, and the options table becomes the mod's `--name value` arguments:

```luau
CodeQuality.transform(CodeQuality.Mod.StringMethodCall, { "src" })
```

From a terminal, pass `lute transform` the mod and the files or folders to rewrite. `<package>` is the vendored package folder under `.lpm`. Preview the changes with `--dry-run` first:

```sh
lute transform <package>/src/mods/stringMethodCall.luau --dry-run src
lute transform <package>/src/mods/stringMethodCall.luau src
```

A mod keeps the rest of each file as written but doesn't reformat the code it changes. Run your formatter afterwards, then the repo's own checks, before you commit.

## Building without darklua

A Roblox build turns the Luau in `src` into code Roblox can run. Darklua does that with a list of rules in `.darklua.json`. Each of these mods replaces one of those rules, so a repo runs only the steps it needs:

| Mod                      | Darklua rule                | Options                                                                         |
| ------------------------ | --------------------------- | ------------------------------------------------------------------------------- |
| `convertRequire`         | `convert_require`           | `sourcemap` (default `sourcemap.json`), `sourceFolder`, `buildFolder`, `ignore` |
| `injectGlobalValue`      | `inject_global_value`       | `globals` (required)                                                            |
| `computeExpression`      | `compute_expression`        | None                                                                            |
| `removeUnusedIfBranch`   | `remove_unused_if_branch`   | None                                                                            |
| `removeUnusedWhile`      | `remove_unused_while`       | None                                                                            |
| `filterAfterEarlyReturn` | `filter_after_early_return` | None                                                                            |
| `removeNilDeclaration`   | `remove_nil_declaration`    | None                                                                            |
| `removeEmptyDo`          | `remove_empty_do`           | None                                                                            |

`lute transform` rewrites files in place, so a build copies `src` into its output folder first and runs one `lute transform` per step on the copy. Pass options after `--`. Run the steps in the order above, which is the order darklua configs list them. `injectGlobalValue` puts in the values the later steps evaluate, and `removeUnusedIfBranch` can leave behind the empty blocks and `do return end` that `filterAfterEarlyReturn` and `removeEmptyDo` clean up.

```sh
rm -rf dist && cp -R src dist
rojo sourcemap build.project.json -o sourcemap.json
lute transform <package>/src/mods/convertRequire.luau dist -- --sourcemap sourcemap.json --sourceFolder src --buildFolder dist
lute transform <package>/src/mods/injectGlobalValue.luau dist -- --globals '{"BUILD_CHANNEL":{"env":"BUILD_CHANNEL"},"__DEV__":false}'
lute transform <package>/src/mods/computeExpression.luau dist
lute transform <package>/src/mods/removeUnusedIfBranch.luau dist
lute transform <package>/src/mods/removeUnusedWhile.luau dist
lute transform <package>/src/mods/filterAfterEarlyReturn.luau dist
lute transform <package>/src/mods/removeNilDeclaration.luau dist
lute transform <package>/src/mods/removeEmptyDo.luau dist
```

`convertRequire` resolves each require the way Luau does on disk, through relative paths, `@self`, and the aliases in the nearest `.config.luau` or `.luaurc`, then looks the file up in the Rojo sourcemap. A `./` or `../` require that finds no file or folder on disk is read against the instance tree instead, the way Roblox would, which covers packages like react-charm that require the link modules Wally puts beside them. The sourcemap describes `src`, not the copy, so `--sourceFolder src --buildFolder dist` tells the mod to resolve `dist/Foo.luau` as `src/Foo.luau`. It stops with an error on a require it can't resolve, where darklua logs a warning and leaves the require alone. For requires that only resolve at runtime, `--ignore` takes a comma-separated list of require strings to leave as they are, and an entry ending in `*` matches every string that starts with it, as in `--ignore "@std/*"`.

`injectGlobalValue` sets every global in one run. `--globals` is a JSON object that maps each global's name to a value such as `true`, `12`, `"prod"`, or `null` for `nil`. A value written as `{"env": "NAME"}` takes the text of that environment variable, and a `"value"` beside it is used when the variable isn't set.

From a Lute script that requires CodeQuality as in [Use](#use), `CodeQuality.build` runs every step above in order. It runs `injectGlobalValue` only when `globals` is given, and takes the same shape as `--globals`:

```luau
-- Copy src to dist and write sourcemap.json first, as above.
CodeQuality.build({
	sourceFolder = "src",
	buildFolder = "dist",
	sourcemap = "sourcemap.json",
	globals = {
		BUILD_CHANNEL = { env = "BUILD_CHANNEL" },
		__DEV__ = false,
	},
})
```

`paths` limits the steps to some of the files and folders in `buildFolder`, and `ignore` takes the list `--ignore` does.

The output means the same as darklua's, but it isn't the same text. Darklua reprints every file, and these mods keep each file as written apart from what they change. A few choices also differ, and each mod's doc comment lists them:

- Folded numbers are written the way `tostring` writes them, so darklua's `12E4` is `120000` here.
- `removeUnusedIfBranch` moves the block of an `if` that always runs into the enclosing block, where darklua always wraps it in `do ... end`. It still wraps a block that declares locals or types, or ends in `return`, `break`, or `continue`.
- When a removed statement or a moved block would leave a statement that opens with `(` right after another one, the mods keep them apart with `;` or `do ... end`. Luau would otherwise read the `(` as a call on the line before.
- A plain copy keeps every file in `src`. Darklua writes only Luau files and turns JSON, TOML, and YAML files into Luau modules, so prune anything the build shouldn't ship. No mod converts those files, since Rojo already syncs a plain `.json` file as a ModuleScript.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT.

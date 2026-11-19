# Code Quality

Shared Luau lint rules, code mods, and formatter configs for flipbook-labs repos.

The house Luau style is written down as prose in [agent-skills](https://github.com/flipbook-labs/agent-skills). Rules that a tool can check belong here instead, so every repo enforces them the same way and nobody has to remember them. Lint rules run under [`lute lint`](https://github.com/luau-lang/lute), and the package is distributed with Loom so each repo pins a known version.

## Rules

The rules come in two folders:

- `src/rules/lints` catches likely bugs, as a replacement for [Selene](https://github.com/Kampfkarren/selene). Each rule is named after the Selene lint it ports and matches its behavior, except for the cases in [Differences from Selene](#differences-from-selene).
- `src/rules/style` enforces the house style.

### Lints

| Rule | What it flags |
| --- | --- |
| `bad_string_escape` | An escape that doesn't exist, like `"\q"`, or a quote escaped where it doesn't need to be |
| `compare_nan` | `x == 0/0`, which is always false; use `x ~= x` |
| `deprecated` | Deprecated standard library functions and fields, such as `table.getn`; deprecated Roblox APIs on `game`, `plugin`, `script`, `workspace`, and `Enum`, such as `workspace:FindPartOnRay` and `Enum.Axis.Left`; and deprecated parameters, such as the second argument to `Instance.new` |
| `empty_loop` | A loop with an empty body |
| `global_usage` | Any use of `_G` that isn't a local |
| `high_cyclomatic_complexity` | A function with more branches, loops, `and`s, and `or`s than `maximum_complexity` allows |
| `if_same_then_else` | An `if` branch whose block repeats an earlier branch of the same `if` |
| `ifs_same_cond` | An `elseif` whose condition repeats an earlier condition of the same `if` |
| `manual_table_clone` | A loop that copies a fresh table's entries one by one, where `table.clone` does the same |
| `mixed_table` | A table constructor with both positional and keyed entries |
| `multiple_statements` | More than one statement on a line |
| `must_use`   | A standard library call whose return value is discarded, as in a `math.max(x, y)` statement |
| `restricted_module_paths` | A module path listed in the `restricted_paths` option |
| `roblox_incorrect_color3_new_bounds` | `Color3.new` with a number outside 0 to 1, as in `Color3.new(255, 0, 0)`; use `Color3.fromRGB` |
| `roblox_manual_fromscale_or_fromoffset` | A `UDim2.new` that sets only scale or only offset, which `UDim2.fromScale` or `UDim2.fromOffset` says more plainly |
| `roblox_suspicious_udim2_new` | A `UDim2.new` call with one to three arguments, when it takes four |
| `shadowing` | A local that redeclares a name already in scope |
| `suspicious_reverse_loop` | `for i = #t, 1 do`, which needs a step of `-1` to count down |
| `unbalanced_assignments` | An assignment with more values than names, or fewer values without a trailing call |
| `unscoped_variables` | An assignment to a name no local declares, which makes a global |

`empty_loop` takes a `comments_count` option. When it's `true`, a loop whose body is only a comment isn't flagged. `multiple_statements` takes a `one_line_if` option: `"break-return-only"` (the default) allows `if x then return end` on one line, `"allow"` allows any one-line `if` with a single statement, and `"deny"` allows none. Set options in `.config.luau`:

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

`high_cyclomatic_complexity` takes one option, `maximum_complexity`, which defaults to `40`. Set it under `lute.lint.ruleconfigs.high_cyclomatic_complexity.options`.

`deprecated` takes an `allow` option, a list of dotted paths to leave alone, such as `table.getn` or `table.*`. A path also allows everything under it. Write a method call with a dot, as in `workspace.FindPartOnRay`.

The Roblox APIs `deprecated` knows about are generated from Roblox's API dump into `src/generated/robloxApiData.luau`, with messages from Roblox's creator-docs reference. A daily workflow reruns `lute run generate-roblox-api` and opens a PR when a new Studio build changes them. Run the script by hand to refresh them sooner.

`shadowing` and `unscoped_variables` take an `ignore_pattern` option, which defaults to `"^_"`. `global_usage` also takes `ignore_pattern`, but it has no default, so every use of `_G` is flagged until a pattern is set; a pattern such as `"^_.*_$"` allows a field like `_G._foo_`. `restricted_module_paths` takes `restricted_paths`, a map from a dotted path such as `"OldLibrary.Utils.deprecatedFunction"` to the message to show for it, and flags nothing until that map is set. These patterns are Lua patterns, not regular expressions.

### Differences from Selene

The lints follow Selene 0.31.0. This section lists every place they don't, so a project moving off Selene knows which results to expect to change.

These apply to every rule:

- Every rule reports at warning severity. Selene reports `compare_nan`, `if_same_then_else`, `ifs_same_cond`, `restricted_module_paths`, `roblox_incorrect_color3_new_bounds`, and `suspicious_reverse_loop` as errors. To match it, set `severity = "error"` in the rule's entry under `ruleconfigs`.
- `high_cyclomatic_complexity` is on by default. Selene ships it off, but Lute has no way to ship a rule off. Set `off = true` in its entry under `ruleconfigs` to turn it off.
- `-- selene: allow(...)` comments are ignored. Use `-- lute-lint-ignore(<rule>)` on the line above the statement.
- Options go in `.config.luau`, not `selene.toml`, and there is no `std` setting. The Roblox lints run in every project, where Selene runs them only when `std` includes `roblox`.
- `ignore_pattern` options take a Lua pattern, not a regular expression. The `"^_"` default behaves the same, but a pattern copied from `selene.toml` may not.

These apply to one rule or a group of them:

| Rule | Difference |
| --- | --- |
| `bad_string_escape` | A malformed or out-of-range escape, like `"\x1"` or `"\u{110000}"`, is a Luau parse error, so the file fails to lint instead of getting this warning. |
| `deprecated`, `must_use` | The standard library lists are hand copies of Selene 0.31.0's `lua51`, `luau`, and `roblox_base` definitions, so they change only when someone updates them. Only globals read through `.` or `:`, like `table.getn`, are checked. Instance methods such as `signal:connect` need the receiver's type and aren't checked. |
| `deprecated` | Roblox APIs follow the API dump as of the last `lute run generate-roblox-api`, not the dump Selene's std was generated from. Messages come from Roblox's creator-docs reference rather than Selene's generic "this property is deprecated." Selene flags only an enum item's legacy names, like `Enum.Axis.Left`. This rule also flags items Roblox tags as deprecated, like `Enum.SortOrder.Custom`, and flags a deprecated enum, like `Enum.Status`, once rather than once per item. |
| `must_use` | A call on a local, like `math.max(x, y)` after `local math = {}`, isn't flagged. Selene flags it. |
| `empty_loop` | `comments_count` counts only a comment inside the loop's body. Selene counts one anywhere in the loop, so `while --[[ready?]] ready do end` passed there. |
| `global_usage` | Only `_G` is flagged. Selene also flags `shared` under its Roblox std. |
| `if_same_then_else`, `ifs_same_cond` | Two names spelled the same but bound differently, such as a local in one branch and a global in another, compare as different. Selene compares them as the same. |
| `manual_table_clone` | The table being copied must be `pairs(t)`, `ipairs(t)`, `next, t`, or a plain `t`. Selene also flags a loop over any other call, as in `for k, v in string.gmatch(text, p) do`, and suggests a `table.clone` that would throw. A local named `pairs`, `ipairs`, or `next`, or a loop over a local set from a call, isn't flagged either. |
| `roblox_incorrect_color3_new_bounds`, `roblox_manual_fromscale_or_fromoffset`, `roblox_suspicious_udim2_new` | Only the globals `Color3` and `UDim2` match. Selene matches the name, so it also flags a local named `Color3`. Argument values are compared as 64-bit floats, not 32-bit, so a value like `1.00000001` that rounds to a bound in 32 bits can disagree. |
| `roblox_suspicious_udim2_new` | A call whose last argument is an unparenthesized call or `...`, as in `UDim2.new(parts())`, isn't flagged, since that argument can supply the remaining values. Selene flags it. |
| `suspicious_reverse_loop` | A hexadecimal end value, as in `for i = #t, 0x10 do`, isn't flagged. Selene flags it. |
| `unscoped_variables` | An assignment to a standard library global with fields, such as `string = ...`, is flagged. Selene skips it. |

Some Selene behavior looks like a bug but is kept, so the same code gets the same result:

- `unbalanced_assignments` treats `(f())` as a call that can fill the remaining names, though the parentheses keep only its first value.
- `multiple_statements` flags the statements inside a one-line function passed as an argument.
- `high_cyclomatic_complexity` doesn't count `else` blocks or the parts of an `if` expression, and treats `t[f()]` as having no side effects.

These Selene lints have no rule here:

- `almost_swapped`, `constant_table_comparison`, `divide_by_zero`, `duplicate_keys`, and `unused_variable` are built into Lute under the same names, as are `empty_if` (as `empty_if_block`) and `parenthese_conditions` (as `parenthesized_conditions`).
- `undefined_variable`, `mismatched_arg_count`, `standard_library`, and `type_check_inside_call` are reported by `luau-lsp analyze` in strict mode.
- `roblox_incorrect_roact_usage` needs Roblox class and property data from Selene's API dump. [#31](https://github.com/flipbook-labs/code-quality/issues/31) tracks porting it.

### Style

| Rule                        | What it asks for                                                                                       |
| --------------------------- | ------------------------------------------------------------------------------------------------------ |
| `annotate_nil_local`        | An annotation on locals that start as `nil`                                                            |
| `explicit_instantiation`    | `useState<<string?>>(nil)` instead of casting a literal argument, as in `useState(nil :: string?)`     |
| `function_type_param_names` | Named parameters in function types: `(storyModule: ModuleScript) -> ()`                                |
| `inline_table`              | One entry per line once a table or table type has more than three entries, or any returned table       |
| `no_alias_local`            | Reading `props.foo` where it's used instead of copying it into `local foo`                             |
| `no_any`                    | `unknown` instead of `any`                                                                             |
| `no_error_field`            | Error fields named `err` or `problem`, not `error`                                                     |
| `no_paren_truncation`       | A local that captures a call's first return value instead of `(f())`                                   |
| `no_tonumber_cast`          | A `nil` check on `tonumber`'s result instead of a cast like `tonumber(s) :: number`                    |
| `prefer_annotation`         | `local items: { Item } = {}` instead of `local items = {} :: { Item }`                                 |
| `prefer_generic_iteration`  | `for k, v in t` instead of `pairs(t)` or `ipairs(t)`                                                   |
| `redundant_path_conversion` | `fs.exists(file)` instead of `fs.exists(tostring(file))` when `file` is visibly a `Path`               |
| `string_method_call`        | `value:find(...)` instead of `string.find(value, ...)`                                                 |
| `string_union_enum`         | A frozen table of named constants alongside an exported union of three or more string literals         |
| `tostring_in_interpolation` | `` `got {value}` `` instead of `` `got {tostring(value)}` ``                                           |

Casting a table to `{ unknown }` or `{ any }`, as React dependency arrays often do, widens it rather than setting a type parameter, so `explicit_instantiation` allows it.

Every rule reports at warning severity. To silence one on a statement, put `-- lute-lint-ignore(<rule>)` on the line above it. `no_any`, `redundant_path_conversion`, and `tostring_in_interpolation` come with fixes that `lute lint --auto-fix` applies.

`explicit_instantiation` also flags a cast on the result of a call whose only argument is a table constructor. It asks for `table.freeze<<Metrics>>({ ... })` instead of `table.freeze({ ... }) :: Metrics`.

`redundant_path_conversion` checks the paths passed to `@std/fs` and `@std/path` functions, matched through whatever local `require` binds them to. It flags `path.format` around any value, but `tostring` only around a value the source shows is a `Path`: an `@std/path` call that returns one, a local or parameter annotated `path.Path` (or a bare `Path` when the file declares `type Path = path.Path`), or a local set from such a call and never reassigned. A `tostring` around anything else, like `fs.exists(tostring(123))`, may be needed, so it's left alone. The `cwd` option of `process.run` only accepts a string, so it's left alone too.

Explicit instantiation needs StyLua's `syntax = "Luau"` setting. Without it, StyLua can't parse `f<<T>>()`.

## Using the rules

Point `lute lint` at a rule folder of the installed package. Declare the package as a dev dependency in `pkg.luau`, under the `code-quality` key:

```luau
dev_dependencies = {
	["code-quality"] = {
		rev = "v0.3.0",
		sourceKind = "github",
		source = "https://github.com/flipbook-labs/code-quality",
	},
},
```

`lute run install` adds a `code-quality` alias to `.config.luau` that points at the installed package. The package exports each rule folder's absolute path, so a Lute script requires it by that alias and doesn't need to know where Loom installed it:

- `LINT_RULES_PATH` is `src/rules/lints`, the Selene replacement.
- `STYLE_RULES_PATH` is `src/rules/style`, the house style.
- `RULES_PATH` is `src/rules`, which runs both.

```luau
local CodeQuality = require("@code-quality")
local process = require("@std/process")

-- Only the Selene replacement. Use RULES_PATH to run the house style too.
process.run({ "lute", "lint", "--sequential", "--rules", CodeQuality.LINT_RULES_PATH, "src" })
```

`--sequential` works around a crash in Lute's parallel linting (#27). `lute lint` keeps only the last `--rules` it's given, so passing the flag once per folder runs just the last one. Lute's built-in rules run alongside these unless you pass `--no-default-lints`.

## Code mods

A code mod rewrites source in place, for a one-time migration or a fix too large for a lint autofix. Mods live in `src/mods` and run under `lute transform`.

| Mod                | What it does                                            |
| ------------------ | ------------------------------------------------------- |
| `stringMethodCall` | Rewrites `string.find(value, ...)` as `value:find(...)` |

`stringMethodCall` fixes what `string_method_call` flags. It leaves a few calls alone because rewriting them could change what the code does: a first argument that can't be a string, like `-5` or `a + b`, a call or `...` passed as the only argument, which may hand over several values, a call with a comment beside its first argument or inside `string.<method>`, and a rewrite that would start a statement with `(`, which Luau could read as a call on the line before. The rule still flags those, so lint afterwards to find any that need a hand edit.

## Running a code mod

Pass `lute transform` the mod and the files or folders to rewrite. `<package>` is the installed package's folder, the one the `code-quality` alias points to in `.config.luau`. Preview the changes with `--dry-run` first:

```sh
lute transform <package>/src/mods/stringMethodCall.luau --dry-run src
lute transform <package>/src/mods/stringMethodCall.luau src
```

A mod keeps the rest of each file as written but doesn't reformat the code it changes. Run your formatter afterwards, then the repo's own checks, before you commit.

## Development

Install the toolchain with [Rokit](https://github.com/rojo-rbx/rokit), then fetch the Lute typedefs:

```sh
rokit install
lute setup
```

Every pull request adds a change entry in `.changes/`, which [Changewrite](https://github.com/flipbook-labs/changewrite) turns into the changelog and the next version. [`.changes/README.md`](.changes/README.md) explains the format.

Run the checks:

```sh
lute run lint
lute run analyze
lute test
```

Each rule lives in `src/rules/lints` or `src/rules/style` with a spec beside it that runs the rule over snippets of source. `lute lint --rules` loads every file in the folder it's given, including the files in its subfolders, and skips the ones that don't return a rule, so the specs ship with the rules and load in any repo that runs them. Keep their requires relative, since a repo alias like `@repo` won't resolve there. Shared helpers go in `src/lib`.

### Adding a rule

1. Add `src/rules/lints/<ruleName>.luau` for a lint that catches likely bugs, or `src/rules/style/<ruleName>.luau` for house style. It returns a frozen `types.LintRule` from `src/types.luau`: a `name` in snake case and a `lint` function that takes the parsed file and returns its violations. Find nodes with `@std/syntax/query` and match them with the `is*` helpers in `@std/syntax/utils`, as the existing rules do. Write against the typedefs for the pinned Lute version in `~/.lute/typedefs`.
2. Add `<ruleName>.spec.luau` beside it. Run snippets through `src/lib/lintSource.luau` and assert on the violations. Cover the code the rule flags and the nearby code it leaves alone.
3. If the rule reports inside a table type, report at `getReportLocation`'s location instead, and add a case to `src/lib/getReportLocation.lute.spec.luau`. Its comment explains why.
4. Add a row to its folder's table above, and a change entry in `.changes/`.

A code mod follows the same pattern in `src/mods`. It returns a frozen table with a `transform` function, which takes the file's parse result and returns replacements for the nodes it rewrites. Its spec runs snippets through `src/lib/transformSource.luau` and compares the rewritten source. When a mod fixes what a rule flags, share the matching code through `src/lib`, as `stringMethodCall` does with `getStringMethodName`.

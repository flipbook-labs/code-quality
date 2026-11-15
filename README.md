# Code Quality

Shared Luau lint rules, code mods, and formatter configs for flipbook-labs repos.

The house Luau style is written down as prose in [agent-skills](https://github.com/flipbook-labs/agent-skills). Rules that a tool can check belong here instead, so every repo enforces them the same way and nobody has to remember them. Lint rules run under [`lute lint`](https://github.com/luau-lang/lute), and the package is distributed with Loom so each repo pins a known version.

## Rules

The rules come in two folders:

- `src/rules/lints` catches likely bugs, as a replacement for [Selene](https://github.com/Kampfkarren/selene). Each rule is named after the Selene lint it ports and matches its behavior.
- `src/rules/style` enforces the house style.

### Lints

| Rule | What it flags |
| --- | --- |
| `bad_string_escape` | An escape that doesn't exist, like `"\q"`, or a quote escaped where it doesn't need to be |
| `compare_nan` | `x == 0/0`, which is always false; use `x ~= x` |
| `deprecated` | Standard library functions and fields that are deprecated, such as `table.getn`, and deprecated parameters, such as the second argument to `Instance.new` |
| `empty_loop` | A loop with an empty body |
| `high_cyclomatic_complexity` | A function with more branches, loops, `and`s, and `or`s than `maximum_complexity` allows |
| `if_same_then_else` | An `if` branch whose block repeats an earlier branch of the same `if` |
| `ifs_same_cond` | An `elseif` whose condition repeats an earlier condition of the same `if` |
| `manual_table_clone` | A loop that copies a fresh table's entries one by one, where `table.clone` does the same |
| `mixed_table` | A table constructor with both positional and keyed entries |
| `multiple_statements` | More than one statement on a line |
| `must_use`   | A standard library call whose return value is discarded, as in a `math.max(x, y)` statement |
| `roblox_incorrect_color3_new_bounds` | `Color3.new` with a number outside 0 to 1, as in `Color3.new(255, 0, 0)`; use `Color3.fromRGB` |
| `roblox_manual_fromscale_or_fromoffset` | A `UDim2.new` that sets only scale or only offset, which `UDim2.fromScale` or `UDim2.fromOffset` says more plainly |
| `roblox_suspicious_udim2_new` | A `UDim2.new` call with one to three arguments, when it takes four |
| `suspicious_reverse_loop` | `for i = #t, 1 do`, which needs a step of `-1` to count down |
| `unbalanced_assignments` | An assignment with more values than names, or fewer values without a trailing call |

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

`high_cyclomatic_complexity` takes one option, `maximum_complexity`, which defaults to `40`. Set it under `lute.lint.ruleconfigs.high_cyclomatic_complexity.options`. Selene ships this lint off; here it's on by default, so a project that doesn't want it turns it off in its config.

`deprecated` takes an `allow` option, a list of dotted paths to leave alone, such as `table.getn` or `table.*`. A path also allows everything under it.

These rules only match the Roblox globals `Color3` and `UDim2`, so a local with the same name is left alone. Selene matches the name alone.

### Style

| Rule                        | What it asks for                                                                                       |
| --------------------------- | ------------------------------------------------------------------------------------------------------ |
| `annotate_nil_local`        | An annotation on locals that start as `nil`                                                            |
| `explicit_instantiation`    | `useState<<string?>>(nil)` instead of casting a literal argument, as in `useState(nil :: string?)`     |
| `function_type_param_names` | Named parameters in function types: `(storyModule: ModuleScript) -> ()`                                |
| `inline_table`              | One field per line once a table has more than two keyed fields, or any keyed field in a returned table |
| `no_alias_local`            | Reading `props.foo` where it's used instead of copying it into `local foo`                             |
| `no_any`                    | `unknown` instead of `any`                                                                             |
| `no_error_field`            | Error fields named `err` or `problem`, not `error`                                                     |
| `no_paren_truncation`       | A local that captures a call's first return value instead of `(f())`                                   |
| `prefer_annotation`         | `local items: { Item } = {}` instead of `local items = {} :: { Item }`                                 |
| `prefer_generic_iteration`  | `for k, v in t` instead of `pairs(t)` or `ipairs(t)`                                                   |
| `string_method_call`        | `value:find(...)` instead of `string.find(value, ...)`                                                 |
| `string_union_enum`         | A frozen table of named constants alongside an exported union of three or more string literals         |
| `tostring_in_interpolation` | `` `got {value}` `` instead of `` `got {tostring(value)}` ``                                           |

Casting a table to `{ unknown }` or `{ any }`, as React dependency arrays often do, widens it rather than setting a type parameter, so `explicit_instantiation` allows it.

Every rule reports at warning severity. To silence one on a statement, put `-- lute-lint-ignore(<rule>)` on the line above it. `no_any` and `tostring_in_interpolation` come with fixes that `lute lint --auto-fix` applies.

`explicit_instantiation` also flags a cast on the result of a call whose only argument is a table constructor. It asks for `table.freeze<<Metrics>>({ ... })` instead of `table.freeze({ ... }) :: Metrics`.

Explicit instantiation needs StyLua's `syntax = "Luau"` setting. Without it, StyLua can't parse `f<<T>>()`.

## Using the rules

Point `lute lint` at a rule folder of the installed package. The package exports each folder's absolute path, so a Lute script doesn't need to know where Loom installed it:

- `LINT_RULES_PATH` is `src/rules/lints`, the Selene replacement.
- `STYLE_RULES_PATH` is `src/rules/style`, the house style.
- `RULES_PATH` is `src/rules`, which runs both.

```luau
local CodeQuality = require("@luaupkg/CodeQuality@v0.3.0")
local process = require("@std/process")

-- Only the Selene replacement. Use RULES_PATH to run the house style too.
process.run({ "lute", "lint", "--sequential", "--rules", CodeQuality.LINT_RULES_PATH, "src" })
```

`--sequential` works around a crash in Lute's parallel linting (#27). `lute lint` keeps only the last `--rules` it's given, so passing the flag once per folder runs just the last one. Lute's built-in rules run alongside these unless you pass `--no-default-lints`.

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

# Code Quality

Shared Luau lint rules, code mods, and formatter configs for flipbook-labs repos.

The house Luau style is written down as prose in [agent-skills](https://github.com/flipbook-labs/agent-skills). Rules that a tool can check belong here instead, so every repo enforces them the same way and nobody has to remember them. Lint rules run under [`lute lint`](https://github.com/luau-lang/lute), and the package is distributed with Loom so each repo pins a known version.

## Rules

The rules come in two folders:

- `src/rules/lints` catches likely bugs, as a replacement for [Selene](https://github.com/Kampfkarren/selene). It has no rules yet.
- `src/rules/style` enforces the house style. It holds these rules:

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

## Code mods

A code mod rewrites source in place, for a one-time migration or a fix too large for a lint autofix. Mods live in `src/mods` and run under `lute transform`.

| Mod                | What it does                                            |
| ------------------ | ------------------------------------------------------- |
| `stringMethodCall` | Rewrites `string.find(value, ...)` as `value:find(...)` |

`stringMethodCall` fixes what `string_method_call` flags. It leaves a few calls alone because rewriting them could change what the code does: a first argument that can't be a string, like `-5` or `a + b`, a call or `...` passed as the only argument, which may hand over several values, a call with a comment beside its first argument or inside `string.<method>`, and a rewrite that would start a statement with `(`, which Luau could read as a call on the line before. The rule still flags those, so lint afterwards to find any that need a hand edit.

## Running a code mod

Pass `lute transform` the mod and the files or folders to rewrite. `<package>` is the installed package's folder, two levels above `RULES_PATH`. Preview the changes with `--dry-run` first:

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

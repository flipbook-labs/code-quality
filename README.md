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
| `global_usage` | Any use of `_G` that isn't a local |
| `restricted_module_paths` | A module path listed in the `restricted_paths` option |
| `shadowing` | A local that redeclares a name already in scope |
| `unscoped_variables` | An assignment to a name no local declares, which makes a global |

`shadowing` and `unscoped_variables` take an `ignore_pattern` option, which defaults to `"^_"`. `global_usage` also takes `ignore_pattern`, but it has no default, so every use of `_G` is flagged until a pattern is set; a pattern such as `"^_.*_$"` allows a field like `_G._foo_`. `restricted_module_paths` takes `restricted_paths`, a map from a dotted path such as `"OldLibrary.Utils.deprecatedFunction"` to the message to show for it, and flags nothing until that map is set. These patterns are Lua patterns, not the regular expressions Selene uses, so only the simple forms carry over unchanged.

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

Point `lute lint` at one rule folder of the installed package, or at `src/rules` for both:

```sh
lute lint --rules <package>/src/rules/lints src
lute lint --rules <package>/src/rules/style src
lute lint --rules <package>/src/rules src
```

`lute lint` keeps only the last `--rules` it's given, so passing the flag once per folder runs just the last one. Lute's built-in rules run alongside these unless you pass `--no-default-lints`.

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

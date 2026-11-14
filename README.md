# Code Quality

Shared Luau lint rules, code mods, and formatter configs for flipbook-labs repos.

The house Luau style is written down as prose in [agent-skills](https://github.com/flipbook-labs/agent-skills). Rules that a tool can check belong here instead, so every repo enforces them the same way and nobody has to remember them. Lint rules run under [`lute lint`](https://github.com/luau-lang/lute), and the package is distributed with Loom so each repo pins a known version.

## Rules

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
| `string_union_enum`         | A frozen table of named constants instead of an exported union of three or more string literals        |
| `tostring_in_interpolation` | `` `got {value}` `` instead of `` `got {tostring(value)}` ``                                           |

Every rule reports at warning severity. To silence one on a statement, put `-- lute-lint-ignore(<rule>)` on the line above it. `no_any`, `tostring_in_interpolation`, and single-argument `explicit_instantiation` calls come with fixes that `lute lint --auto-fix` applies.

Explicit instantiation needs StyLua's `syntax = "Luau"` setting. Without it, StyLua can't parse `f<<T>>()`.

## Using the rules

Point `lute lint` at the `src/rules` folder of the installed package:

```sh
lute lint --rules <package>/src/rules src
```

## Development

Install the toolchain with [Rokit](https://github.com/rojo-rbx/rokit), then fetch the Lute typedefs:

```sh
rokit install
lute setup
```

Run the checks:

```sh
lute run lint
lute run analyze
lute test
```

Each rule lives in `src/rules` and has a spec in `tests` that runs it over snippets of source. Keep specs and helpers out of `src/rules`, because `lute lint --rules` loads every file in that folder as a rule.

# Code Quality

Shared Luau lint rules, code mods, and formatter configs for flipbook-labs repos.

The house Luau style is written down as prose in [agent-skills](https://github.com/flipbook-labs/agent-skills). Rules that a tool can check belong here instead, so every repo enforces them the same way and nobody has to remember them. Lint rules run under [`lute lint`](https://github.com/luau-lang/lute), and the package is distributed with Loom so each repo pins a known version.

## Rules

| Rule                        | What it asks for                                                                                   |
| --------------------------- | -------------------------------------------------------------------------------------------------- |
| `explicit_instantiation`    | `useState<<string?>>(nil)` instead of casting a literal argument, as in `useState(nil :: string?)` |
| `function_type_param_names` | Named parameters in function types: `(storyModule: ModuleScript) -> ()`                            |
| `inline_table`              | One field per line once a table has more than two keyed fields                                     |
| `no_any`                    | `unknown` instead of `any`                                                                         |
| `no_error_field`            | Error fields named `err` or `problem`, not `error`                                                 |
| `string_method_call`        | `value:find(...)` instead of `string.find(value, ...)`                                             |
| `tostring_in_interpolation` | `` `got {value}` `` instead of `` `got {tostring(value)}` ``                                       |

Every rule reports at warning severity. `no_any` and `tostring_in_interpolation` come with fixes that `lute lint --auto-fix` applies.

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

Each rule lives in `src/rules` with a spec beside it that runs the rule over snippets of source. `lute lint --rules` loads every file in that folder and skips the ones that don't return a rule, so the specs ship with the rules and load in any repo that runs them. Keep their requires relative, since a repo alias like `@repo` won't resolve there. Shared helpers go in `src/lib`.

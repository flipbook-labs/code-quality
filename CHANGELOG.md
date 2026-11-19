# Changelog

All notable changes to this project will be documented in this file.


## v0.4.0

Features 6 · Changes 1 · Internal 1

### Features

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.png" alt="Lint rules" height="18" align="texttop"></picture> Add the first Selene replacements in `src/rules/lints`: `bad_string_escape`, `compare_nan`, `empty_loop`, `mixed_table`, `multiple_statements`, `suspicious_reverse_loop`, and `unbalanced_assignments`. ([#19](https://github.com/flipbook-labs/code-quality/pull/19))
2. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.png" alt="Lint rules" height="18" align="texttop"></picture> Add `lute lint` rules for Selene's `if_same_then_else`, `ifs_same_cond`, `manual_table_clone`, and `high_cyclomatic_complexity`, the last with a `maximum_complexity` option that defaults to 40. ([#24](https://github.com/flipbook-labs/code-quality/pull/24))
3. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.png" alt="Lint rules" height="18" align="texttop"></picture> Add the `deprecated` and `must_use` lints, ports of Selene's lints for standard library calls. They check against a hand-maintained list of standard library functions in place of Selene's definitions. ([#23](https://github.com/flipbook-labs/code-quality/pull/23))
4. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.png" alt="Lint rules" height="18" align="texttop"></picture> Add `shadowing`, `unscoped_variables`, `global_usage`, and `restricted_module_paths` lint rules, ported from Selene. The first three track which names are in scope, and `restricted_module_paths` flags the module paths listed in its `restricted_paths` option. ([#26](https://github.com/flipbook-labs/code-quality/pull/26))
5. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.png" alt="Lint rules" height="18" align="texttop"></picture> Add the `roblox_incorrect_color3_new_bounds`, `roblox_manual_fromscale_or_fromoffset`, and `roblox_suspicious_udim2_new` lint rules, ported from Selene. They flag `Color3.new` values outside 0 to 1, `UDim2.new` calls that set only scale or only offset, and `UDim2.new` calls with one to three arguments. ([#21](https://github.com/flipbook-labs/code-quality/pull/21))
6. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.png" alt="Lint rules" height="18" align="texttop"></picture> `deprecated` flags deprecated Roblox APIs read off `game`, `plugin`, `script`, and `workspace`, such as `workspace:FindPartOnRay`, and deprecated or renamed `Enum` items, such as `Enum.Axis.Left`. The list is generated from Roblox's API dump with `lute run generate-roblox-api`, and messages come from Roblox's creator-docs reference. ([#36](https://github.com/flipbook-labs/code-quality/pull/36))

### Changes

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-packaging-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-packaging-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-packaging-light.png" alt="Packaging" height="18" align="texttop"></picture> Move the house-style rules to `src/rules/style` and add `src/rules/lints` for the upcoming Selene replacement. Point `lute lint --rules` at either folder, or at `src/rules` for both. The package exports their paths as `LINT_RULES_PATH` and `STYLE_RULES_PATH`, alongside `RULES_PATH` for both. ([#15](https://github.com/flipbook-labs/code-quality/pull/15))

<details>
<summary>Internal (1)</summary>

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-docs-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-docs-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-docs-light.png" alt="Docs" height="18" align="texttop"></picture> Document requiring the package through its `code-quality` alias and declaring it under that key in `pkg.luau`, in place of the Loom store path. ([#33](https://github.com/flipbook-labs/code-quality/pull/33))

</details>


## v0.3.0

Features 3 · Internal 1

### Features

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-packaging-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-packaging-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-packaging-light.png" alt="Packaging" height="18" align="texttop"></picture> Export `RULES_PATH`, the absolute path of the installed rules folder, so repos can pass it to `lute lint --rules` without building a path into the Loom store. ([#28](https://github.com/flipbook-labs/code-quality/pull/28))
2. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.png" alt="Lint rules" height="18" align="texttop"></picture> Add `redundant_path_conversion`, which flags a `tostring(x)` or `path.format(x)` passed to an `@std/fs` or `@std/path` function that already takes a `Pathlike`. It flags `tostring` only when `x` is visibly a `Path`. Also add `no_tonumber_cast`, which flags casts like `tonumber(s) :: number` that hide the `nil` `tonumber` can return. ([#16](https://github.com/flipbook-labs/code-quality/pull/16))
3. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-mods-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-mods-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-mods-light.png" alt="Code mods" height="18" align="texttop"></picture> Add the first code mod, `src/mods/stringMethodCall.luau`, which rewrites `string.find(value, ...)` as `value:find(...)` under `lute transform`. The README now explains how to add a rule and how to run a code mod. ([#17](https://github.com/flipbook-labs/code-quality/pull/17))

<details>
<summary>Internal (1)</summary>

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-release-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-release-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-release-light.png" alt="Release" height="18" align="texttop"></picture> Release with Changewrite v0.12.0, which reads the `pkg.luau` version without a custom pattern. ([#30](https://github.com/flipbook-labs/code-quality/pull/30))

</details>


## v0.2.0

Features 1 · Fixes 1 · Changes 1 · Internal 2

### Features

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.png" alt="Lint rules" height="18" align="texttop"></picture> `explicit_instantiation` now also flags a cast on the result of a call whose only argument is a table constructor, such as `table.freeze({ ... }) :: Metrics`, and asks for `table.freeze<<Metrics>>({ ... })` instead. ([#8](https://github.com/flipbook-labs/code-quality/pull/8))

### Fixes

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-rules-light.png" alt="Lint rules" height="18" align="texttop"></picture> `explicit_instantiation` allows a table cast to `{ unknown }` or `{ any }`, and `string_union_enum` allows a union whose values a frozen table in the same module already holds. ([#9](https://github.com/flipbook-labs/code-quality/pull/9))

### Changes

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-packaging-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-packaging-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-packaging-light.png" alt="Packaging" height="18" align="texttop"></picture> Ship the manifest as `pkg.luau`, which installs only with Lute nightlies newer than `1.0.1-nightly.20261031`. ([#18](https://github.com/flipbook-labs/code-quality/pull/18))

<details>
<summary>Internal (2)</summary>

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-tooling-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-tooling-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop"></picture> Lint this repo one file at a time, since Lute's parallel linting can crash at random. ([#11](https://github.com/flipbook-labs/code-quality/pull/11))
2. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-release-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-release-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/code-quality/main/.changes/assets/kind-release-light.png" alt="Release" height="18" align="texttop"></picture> Upgrade Changewrite to `v0.11.1`, so release notes mark each entry with a chip naming what it changed, such as Lint rules or Code mods, and collapse the Internal section. ([#25](https://github.com/flipbook-labs/code-quality/pull/25))

</details>


## v0.1.0

### Features

- Add the first shared Luau lint rules. The README lists each one and what it asks for.

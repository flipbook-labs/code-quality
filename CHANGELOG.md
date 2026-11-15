# Changelog

All notable changes to this project will be documented in this file.


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

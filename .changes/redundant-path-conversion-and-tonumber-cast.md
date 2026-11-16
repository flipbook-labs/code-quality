---
bump: minor
category: Features
kind: rules
---

Add `redundant_path_conversion`, which flags a `tostring(x)` or `path.format(x)` passed to an `@std/fs` or `@std/path` function that already takes a `Pathlike`. It flags `tostring` only when `x` is visibly a `Path`. Also add `no_tonumber_cast`, which flags casts like `tonumber(s) :: number` that hide the `nil` `tonumber` can return.

---
bump: minor
category: Features
---

Add `redundant_path_conversion`, which flags `tostring(x)` or `path.format(x)` passed to an `@std/fs` or `@std/path` function that already takes a `Pathlike`, and `no_tonumber_cast`, which flags casts like `tonumber(s) :: number` that hide the `nil` `tonumber` can return.

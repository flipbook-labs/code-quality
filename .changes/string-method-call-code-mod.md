---
bump: minor
category: Features
---

Add the first code mod, `src/mods/stringMethodCall.luau`, which rewrites `string.find(value, ...)` as `value:find(...)` under `lute transform`. The README now explains how to add a rule and how to run a code mod.

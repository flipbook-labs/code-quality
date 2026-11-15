---
bump: minor
category: Features
---

`explicit_instantiation` now also flags a cast on the result of a call whose only argument is a table constructor, such as `table.freeze({ ... }) :: Metrics`, and asks for `table.freeze<<Metrics>>({ ... })` instead.

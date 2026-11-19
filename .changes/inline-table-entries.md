---
bump: minor
category: Changes
kind: rules
---

`inline_table` now counts every entry: array elements, keyed fields and `[key] = value` fields count the same, and table types follow the same limit, with each property or indexer as one entry. A table or table type with more than three entries on one line is flagged, as is any returned table with at least one entry, now including a list such as `return { a, b }`. Expect new findings after upgrading.

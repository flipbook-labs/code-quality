---
bump: minor
category: Features
kind: mods
---

`convertRequire` reads a `./` or `../` require with no file on disk against the sourcemap's instance tree, so it can convert packages like react-charm that require the link modules Wally installs beside them.

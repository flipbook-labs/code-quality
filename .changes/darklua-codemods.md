---
bump: minor
category: Features
kind: mods
highlight: Code mods that replace darklua
---

Add eight code mods that each replace one darklua rule a build uses: `convertRequire`, `injectGlobalValue`, `computeExpression`, `removeUnusedIfBranch`, `removeUnusedWhile`, `filterAfterEarlyReturn`, `removeNilDeclaration`, and `removeEmptyDo`. A build copies `src` and runs `lute transform` once per step it needs, as the README's "Building without darklua" section shows.

local path = require("@std/path")

-- Repos run these rules by passing the `src/rules` folder to `lute lint
-- --rules`. Loom installs the package in a folder named after its version, in a
-- store under the home folder, so that path changes with every pin. Lute reports
-- this file's own path as its source, which leads to the rules folder beside it
-- wherever the package lives.
local sourcePath = path.resolve(debug.info(1, "s"))

-- The absolute path of the rules folder.
return path.format(path.join(path.dirname(sourcePath), "rules"))

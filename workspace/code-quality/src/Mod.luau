-- Names for the code mods in `src/mods`, for `CodeQuality.transform`. Each
-- value is the mod's file name without `.luau`.
export type Mod =
	"computeExpression"
	| "convertRequire"
	| "filterAfterEarlyReturn"
	| "injectGlobalValue"
	| "removeEmptyDo"
	| "removeNilDeclaration"
	| "removeUnusedIfBranch"
	| "removeUnusedWhile"
	| "stringMethodCall"

local Mod = table.freeze({
	ComputeExpression = "computeExpression" :: "computeExpression",
	ConvertRequire = "convertRequire" :: "convertRequire",
	FilterAfterEarlyReturn = "filterAfterEarlyReturn" :: "filterAfterEarlyReturn",
	InjectGlobalValue = "injectGlobalValue" :: "injectGlobalValue",
	RemoveEmptyDo = "removeEmptyDo" :: "removeEmptyDo",
	RemoveNilDeclaration = "removeNilDeclaration" :: "removeNilDeclaration",
	RemoveUnusedIfBranch = "removeUnusedIfBranch" :: "removeUnusedIfBranch",
	RemoveUnusedWhile = "removeUnusedWhile" :: "removeUnusedWhile",
	StringMethodCall = "stringMethodCall" :: "stringMethodCall",
})

return Mod

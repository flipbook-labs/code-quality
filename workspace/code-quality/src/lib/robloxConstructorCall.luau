local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

-- Returns the arguments when `call` is `<className>.new(...)` written with
-- parentheses, as in `Color3.new(1, 0, 0)`, and nil for anything else. Only a
-- global name counts, so a local called `Color3` is left alone. Selene matches
-- the name alone, so this is stricter than Selene on that point. Calls written
-- as `Color3.new "x"` or `Color3.new {}` are skipped, as Selene does.
local function constructorArguments(call: syntax.CstExprCall, className: string): syntax.CstPunctuated<syntax.CstExpr>?
	if call.openParens == nil then
		return nil
	end

	local index = utils.isExprIndexName(call.func)
	if not index or index.accessor.text ~= "." or index.index.text ~= "new" then
		return nil
	end

	local global = utils.isExprGlobal(index.expression)
	if not global or global.name.text ~= className then
		return nil
	end

	return call.arguments
end

return constructorArguments

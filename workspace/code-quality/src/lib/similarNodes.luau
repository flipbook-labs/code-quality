--[[
	Structural equality for Luau CST nodes, ignoring trivia (whitespace and
	comments) and source positions. Two nodes are similar when they hold the same
	tokens in the same shape, so `print( x )` and `print(x)` match, while
	`'a'` and `"a"` do not.
]]

-- Keys that hold positions, trivia, or name resolution rather than syntax.
-- Resolution is skipped so two `x` reads match by name, as Selene compares them.
local function isIgnoredKey(key: unknown): boolean
	return key == "location"
		or key == "indexLocation"
		or key == "argLocation"
		or key == "leadingTrivia"
		or key == "trailingTrivia"
		or key == "local"
		or key == "shadows"
		or key == "upvalue"
end

local function similarValues(a: unknown, b: unknown): boolean
	if a == b then
		return true
	end
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return false
	end

	local left = a :: { [unknown]: unknown }
	local right = b :: { [unknown]: unknown }
	for key, value in left do
		if not isIgnoredKey(key) and not similarValues(value, right[key]) then
			return false
		end
	end
	for key in right do
		if not isIgnoredKey(key) and left[key] == nil then
			return false
		end
	end
	return true
end

-- Whether two CST nodes are the same code once trivia is ignored.
local function similarNodes(a: unknown, b: unknown): boolean
	return similarValues(a, b)
end

return similarNodes

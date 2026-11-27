-- Reads an `ignore_pattern` option. Selene takes a regular expression here,
-- but Luau has no regex library, so the pattern is a Lua pattern. The
-- default patterns, like "^_", mean the same in both.
local function readIgnorePattern(options: { [string]: unknown }, key: string, default: string?): string?
	local value = options[key]
	if value == nil then
		return default
	end

	if typeof(value) ~= "string" then
		error(`{key} must be a string`)
	end

	if not pcall(function()
		return string.find("", value)
	end) then
		error(`{key} is not a valid Lua pattern: {value}`)
	end

	return value
end

local function isIgnored(pattern: string?, name: string): boolean
	return pattern ~= nil and name:find(pattern) ~= nil
end

return {
	read = readIgnorePattern,
	isIgnored = isIgnored,
}

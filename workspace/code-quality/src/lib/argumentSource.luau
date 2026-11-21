local printer = require("@std/syntax/printer")
local syntax = require("@std/syntax")

-- Source text of an expression with the surrounding whitespace removed. Selene
-- matches on an argument's text rather than its value, so the Roblox
-- constructor rules match on this too.
local function text(expr: syntax.CstExpr): string
	return printer.printNode(expr):match("^%s*(.-)%s*$") or ""
end

-- The number that `expr` spells, for the decimal forms Rust's `f32` parser
-- accepts: an optional sign, digits with an optional fraction, and an optional
-- exponent. Hex, binary, underscores, and `inf` or `nan` give nil. Selene reads
-- `inf` and `nan` as numbers because Rust does, but in Luau they're just names.
-- Values are compared as f64 here, not f32, so a value that rounds to a bound
-- in f32 (like `1.00000001`) can differ from Selene.
local function decimal(expr: syntax.CstExpr): number?
	local source = text(expr)
	local negative = source:sub(1, 1) == "-"
	local body = if source:sub(1, 1) == "-" or source:sub(1, 1) == "+" then source:sub(2) else source

	local mantissa = body:match("^([^eE]*)[eE]") or body
	local exponent = body:match("^[^eE]*([eE].*)$") or ""

	local validMantissa = mantissa:match("^%d+%.?%d*$") ~= nil or mantissa:match("^%.%d+$") ~= nil
	if not validMantissa then
		return nil
	end

	if exponent ~= "" and exponent:match("^[eE][+-]?%d+$") == nil then
		return nil
	end

	local value = tonumber(mantissa .. exponent)
	if value == nil then
		return nil
	end

	return if negative then -value else value
end

return table.freeze({
	text = text,
	decimal = decimal,
})

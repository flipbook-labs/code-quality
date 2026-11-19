-- The standard library entries the `deprecated` and `must_use` rules check.
--
-- Selene reads these from its `default_std` definitions, which cover every field,
-- function, and method in the standard library. The lists here copy the global
-- functions from Selene 0.31.0's `lua51.yml`, `luau.yml`, and `roblox_base.yml`,
-- which its `roblox` standard library builds on. Deprecated Roblox engine APIs,
-- such as `workspace:FindPartOnRay`, come from robloxApi.luau instead, which is
-- generated from Roblox's API dump.
--
-- Methods on values, such as `signal:connect(...)`, aren't listed. A rule that
-- reads syntax can't tell what type a value has, so it can't tell which
-- `connect` a call refers to.

export type Deprecation = {
	-- The dotted path to the function or field, as in `table.getn`.
	path: string,
	message: string,
	-- Selene's replacement template, where `%1` stands for the first argument.
	replace: string?,
}

export type DeprecatedParameter = {
	path: string,
	-- The 1-based position of the parameter.
	index: number,
	message: string,
}

local function deprecation(path: string, message: string, replace: string?): Deprecation
	return {
		path = path,
		message = message,
		replace = replace,
	}
end

local DEPRECATIONS: { Deprecation } = table.freeze({
	deprecation("table.foreach", "use a for loop instead.", nil),
	deprecation("table.foreachi", "use a for loop instead.", nil),
	deprecation("table.getn", "`table.getn` has been superseded by #.", "#%1"),
})

local DEPRECATED_PARAMETERS: { DeprecatedParameter } = table.freeze({
	{
		path = "Instance.new",
		index = 2,
		message = "set the instance's parent separately",
	},
})

-- Functions whose return value is the point of the call, so a statement that
-- discards it is probably a mistake.
local MUST_USE: { string } = table.freeze({
	"Axes.new",
	"BrickColor.Black",
	"BrickColor.Blue",
	"BrickColor.DarkGray",
	"BrickColor.Gray",
	"BrickColor.Green",
	"BrickColor.Red",
	"BrickColor.White",
	"BrickColor.Yellow",
	"BrickColor.new",
	"BrickColor.palette",
	"BrickColor.random",
	"CFrame.Angles",
	"CFrame.fromAxisAngle",
	"CFrame.fromEulerAngles",
	"CFrame.fromEulerAnglesXYZ",
	"CFrame.fromEulerAnglesYXZ",
	"CFrame.fromMatrix",
	"CFrame.fromOrientation",
	"CFrame.fromRotationBetweenVectors",
	"CFrame.lookAlong",
	"CFrame.lookAt",
	"CFrame.new",
	"CatalogSearchParams.new",
	"Color3.fromHSV",
	"Color3.fromHex",
	"Color3.fromRGB",
	"Color3.new",
	"Color3.toHSV",
	"ColorSequence.new",
	"ColorSequenceKeypoint.new",
	"Content.fromObject",
	"Content.fromUri",
	"DateTime.fromIsoDate",
	"DateTime.fromLocalTime",
	"DateTime.fromUniversalTime",
	"DateTime.fromUnixTimestamp",
	"DateTime.fromUnixTimestampMillis",
	"DateTime.now",
	"DebuggerManager",
	"DockWidgetPluginGuiInfo.new",
	"Enum.GetEnums",
	"Faces.new",
	"FloatCurveKey.new",
	"Font.fromEnum",
	"Font.fromId",
	"Font.fromName",
	"Font.new",
	"Instance.fromExisting",
	"Instance.new",
	"NumberRange.new",
	"NumberSequence.new",
	"NumberSequenceKeypoint.new",
	"OverlapParams.new",
	"Path2DControlPoint.new",
	"PathWaypoint.new",
	"PhysicalProperties.new",
	"Random.new",
	"Ray.new",
	"RaycastParams.new",
	"Rect.new",
	"Region3.new",
	"Region3int16.new",
	"RotationCurveKey.new",
	"SharedTable.clone",
	"SharedTable.cloneAndFreeze",
	"SharedTable.isFrozen",
	"SharedTable.new",
	"SharedTable.size",
	"TweenInfo.new",
	"UDim.new",
	"UDim2.fromOffset",
	"UDim2.fromScale",
	"UDim2.new",
	"UserSettings",
	"Vector2.new",
	"Vector2int16.new",
	"Vector3.FromAxis",
	"Vector3.FromNormalId",
	"Vector3.new",
	"bit32.arshift",
	"bit32.band",
	"bit32.bnot",
	"bit32.bor",
	"bit32.btest",
	"bit32.bxor",
	"bit32.byteswap",
	"bit32.countlz",
	"bit32.countrz",
	"bit32.extract",
	"bit32.lrotate",
	"bit32.lshift",
	"bit32.replace",
	"bit32.rrotate",
	"bit32.rshift",
	"buffer.create",
	"buffer.fromstring",
	"buffer.len",
	"buffer.readf32",
	"buffer.readf64",
	"buffer.readi16",
	"buffer.readi32",
	"buffer.readi8",
	"buffer.readstring",
	"buffer.readu16",
	"buffer.readu32",
	"buffer.readu8",
	"buffer.tostring",
	"collectgarbage",
	"coroutine.create",
	"coroutine.running",
	"coroutine.status",
	"debug.getfenv",
	"debug.gethook",
	"debug.getinfo",
	"debug.getlocal",
	"debug.getmetatable",
	"debug.getregistry",
	"debug.getupvalue",
	"debug.info",
	"debug.traceback",
	"gcinfo",
	"getfenv",
	"getmetatable",
	"ipairs",
	"math.abs",
	"math.acos",
	"math.asin",
	"math.atan",
	"math.atan2",
	"math.ceil",
	"math.clamp",
	"math.cos",
	"math.cosh",
	"math.deg",
	"math.exp",
	"math.floor",
	"math.fmod",
	"math.frexp",
	"math.ldexp",
	"math.lerp",
	"math.log",
	"math.log10",
	"math.map",
	"math.max",
	"math.min",
	"math.modf",
	"math.noise",
	"math.pow",
	"math.rad",
	"math.random",
	"math.round",
	"math.sign",
	"math.sin",
	"math.sinh",
	"math.sqrt",
	"math.tan",
	"math.tanh",
	"newproxy",
	"os.clock",
	"os.date",
	"os.difftime",
	"os.time",
	"os.tmpname",
	"pairs",
	"rawequal",
	"rawget",
	"rawlen",
	"select",
	"string.char",
	"string.dump",
	"string.find",
	"string.format",
	"string.gmatch",
	"string.gsub",
	"string.len",
	"string.lower",
	"string.match",
	"string.pack",
	"string.packsize",
	"string.rep",
	"string.reverse",
	"string.split",
	"string.sub",
	"string.unpack",
	"string.upper",
	"table.clone",
	"table.concat",
	"table.create",
	"table.find",
	"table.getn",
	"table.isfrozen",
	"table.maxn",
	"table.pack",
	"table.unpack",
	"tonumber",
	"tostring",
	"unpack",
	"utf8.char",
	"utf8.codepoint",
	"utf8.codes",
	"utf8.graphemes",
	"utf8.len",
	"utf8.nfcnormalize",
	"utf8.nfdnormalize",
	"utf8.offset",
	"vector.abs",
	"vector.angle",
	"vector.ceil",
	"vector.clamp",
	"vector.create",
	"vector.cross",
	"vector.dot",
	"vector.floor",
	"vector.magnitude",
	"vector.max",
	"vector.min",
	"vector.normalize",
	"vector.sign",
})

local standardLibrary = {}

function standardLibrary.getDeprecation(path: string): Deprecation?
	for _, entry in DEPRECATIONS do
		if entry.path == path then
			return entry
		end
	end
	return nil
end

function standardLibrary.getDeprecatedParameter(path: string, index: number): string?
	for _, parameter in DEPRECATED_PARAMETERS do
		if parameter.path == path and parameter.index == index then
			return parameter.message
		end
	end
	return nil
end

function standardLibrary.isMustUse(path: string): boolean
	return table.find(MUST_USE, path) ~= nil
end

return table.freeze(standardLibrary)

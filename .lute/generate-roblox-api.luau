-- Regenerates workspace/code-quality/src/generated/robloxApiData.luau, the
-- Roblox deprecations the `deprecated` rule checks. Run it with
-- `lute run generate-roblox-api`.
--
-- Roblox's API dump for the current Studio build decides what's deprecated: an
-- enum, member, or enum item tagged `Deprecated`, or an enum item's legacy
-- name. The dump is public, so no account or API key is needed, and it's the
-- same data Selene builds its Roblox standard library from.
--
-- The dump doesn't say why something is deprecated. So a message comes from
-- the class or enum's YAML page in Roblox's creator-docs repository, under
-- `DOCS_URL`, with a generic message when the page has none. A legacy name
-- always gets the same fixed message, and its suggested replacement is the
-- item's current name.

local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@std/net")
local process = require("@std/process")

local robloxDocs = require("./lib/robloxDocs")

local OUTPUT_PATH = "workspace/code-quality/src/generated/robloxApiData.luau"
local SETUP_URL = "https://setup.rbxcdn.com"
local DOCS_URL = "https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine"

-- The globals a rule can match from syntax alone, and the class each one
-- holds. These are the globals Selene types in its Roblox standard library.
local GLOBALS: { [string]: string } = {
	game = "DataModel",
	plugin = "Plugin",
	script = "Script",
	workspace = "Workspace",
}

local FALLBACK_MESSAGE = "Check the Roblox API reference for a replacement."
local LEGACY_NAME_MESSAGE = "This is an old name for the same item."

type ApiMember = {
	Name: string,
	MemberType: string,
	Tags: { string }?,
}

type ApiClass = {
	Name: string,
	Superclass: string,
	Members: { ApiMember },
}

type ApiEnumItem = {
	Name: string,
	Tags: { string }?,
	LegacyNames: { string }?,
}

type ApiEnum = {
	Name: string,
	Tags: { string }?,
	Items: { ApiEnumItem },
}

type ApiDump = {
	Classes: { ApiClass },
	Enums: { ApiEnum },
}

type Entry = {
	message: string,
	replace: string?,
}

local function fetch(url: string): string?
	local response = net.request(url)
	if response.status == 404 then
		return nil
	end
	if not response.ok then
		error(`GET {url} failed with status {response.status}`)
	end
	return response.body
end

local function isDeprecated(tags: { string }?): boolean
	return tags ~= nil and table.find(tags, "Deprecated") ~= nil
end

local function isIdentifier(name: string): boolean
	return name:match("^[%a_][%w_]*$") ~= nil
end

local docsCache: { [string]: robloxDocs.DocsMessages } = {}

local function getDocs(kind: "classes" | "enums", name: string): robloxDocs.DocsMessages
	local key = `{kind}/{name}`
	local cached = docsCache[key]
	if cached then
		return cached
	end
	local source = fetch(`{DOCS_URL}/{kind}/{name}.yaml`)
	local messages = if source then robloxDocs.parse(source) else robloxDocs.empty()
	docsCache[key] = messages
	return messages
end

local function quote(text: string): string
	return `"{text:gsub("\\", "\\\\"):gsub('"', '\\"')}"`
end

local function sortedKeys<T>(map: { [string]: T }): { string }
	local keys: { string } = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function writeEntries(out: { string }, indent: string, entries: { [string]: Entry })
	for _, key in sortedKeys(entries) do
		local entry = entries[key]
		local name = if isIdentifier(key) then key else `[{quote(key)}]`
		if entry.replace then
			table.insert(out, `{indent}{name} = \{`)
			table.insert(out, `{indent}\tmessage = {quote(entry.message)},`)
			table.insert(out, `{indent}\treplace = {quote(entry.replace)},`)
			table.insert(out, `{indent}},`)
		else
			table.insert(out, `{indent}{name} = \{ message = {quote(entry.message)} },`)
		end
	end
end

local studioVersion = fetch(`{SETUP_URL}/versionQTStudio`)
assert(studioVersion, "couldn't read the current Studio version")
local dumpSource = fetch(`{SETUP_URL}/{studioVersion}-Full-API-Dump.json`)
assert(dumpSource, `couldn't download the API dump for {studioVersion}`)
local dump = (json.deserialize(dumpSource) :: unknown) :: ApiDump

local classesByName: { [string]: ApiClass } = {}
for _, class in dump.Classes do
	classesByName[class.Name] = class
end

-- Each global gets the deprecated members of its class and every superclass,
-- so `workspace` picks up `Instance:clone` through `Model` and `PVInstance`.
-- When a class and its superclass both list a member, the class's entry wins.
local globalMembers: { [string]: { [string]: Entry } } = {}
for globalName, className in GLOBALS do
	local entries: { [string]: Entry } = {}
	local class: ApiClass? = classesByName[className]
	while class do
		local docs = getDocs("classes", class.Name)
		for _, member in class.Members do
			if isDeprecated(member.Tags) and entries[member.Name] == nil then
				entries[member.Name] = {
					message = docs.items[member.Name] or FALLBACK_MESSAGE,
				}
			end
		end
		class = classesByName[class.Superclass]
	end
	globalMembers[globalName] = entries
end

local enums: { [string]: Entry } = {}
local enumItems: { [string]: Entry } = {}
for _, enum in dump.Enums do
	local hasDeprecations = isDeprecated(enum.Tags)
	for _, item in enum.Items do
		if isDeprecated(item.Tags) then
			hasDeprecations = true
		end
	end
	local docs = if hasDeprecations then getDocs("enums", enum.Name) else robloxDocs.empty()

	-- A deprecated enum's items aren't listed on their own, so a use such as
	-- `Enum.Status.Poison` gets one warning, for the enum, rather than two.
	if isDeprecated(enum.Tags) then
		enums[enum.Name] = {
			message = docs.page or FALLBACK_MESSAGE,
		}
		continue
	end

	for _, item in enum.Items do
		if isDeprecated(item.Tags) then
			enumItems[`{enum.Name}.{item.Name}`] = {
				message = docs.items[item.Name] or FALLBACK_MESSAGE,
			}
		end
		-- A legacy name with a space, like `Mouse Lock Switch`, can't be
		-- written after a dot, so syntax never reaches it.
		for _, legacyName in item.LegacyNames or {} do
			if isIdentifier(legacyName) then
				enumItems[`{enum.Name}.{legacyName}`] = {
					message = LEGACY_NAME_MESSAGE,
					replace = `Enum.{enum.Name}.{item.Name}`,
				}
			end
		end
	end
end

local out: { string } = {
	"-- Generated by `lute run generate-roblox-api` from Roblox's API dump and its",
	"-- creator-docs reference. Don't edit by hand; rerun the script to pick up a",
	"-- newer Roblox API.",
	"",
	"export type Entry = {",
	"\tmessage: string,",
	"\t-- The path to use instead, when there's a direct replacement.",
	"\treplace: string?,",
	"}",
	"",
	"export type RobloxApiData = {",
	"\t-- The Studio build whose API dump this was generated from.",
	"\tstudioVersion: string,",
	"\t-- Deprecated members of each global, by global name and then member name.",
	"\tglobals: { [string]: { [string]: Entry } },",
	"\t-- Deprecated enums, by enum name.",
	"\tenums: { [string]: Entry },",
	"\t-- Deprecated enum items and legacy item names, keyed without the `Enum.`",
	"\t-- prefix, as in `Axis.Left`.",
	"\tenumItems: { [string]: Entry },",
	"}",
	"",
	"local data: RobloxApiData = {",
	`\tstudioVersion = {quote(studioVersion)},`,
	"\tglobals = {",
}
for _, globalName in sortedKeys(globalMembers) do
	table.insert(out, `\t\t{globalName} = \{`)
	writeEntries(out, "\t\t\t", globalMembers[globalName])
	table.insert(out, "\t\t},")
end
table.insert(out, "\t},")
table.insert(out, "\tenums = {")
writeEntries(out, "\t\t", enums)
table.insert(out, "\t},")
table.insert(out, "\tenumItems = {")
writeEntries(out, "\t\t", enumItems)
table.insert(out, "\t},")
table.insert(out, "}")
table.insert(out, "")
table.insert(out, "return data")
table.insert(out, "")

fs.writeStringToFile(OUTPUT_PATH, table.concat(out, "\n"))

local format = process.run({ "stylua", OUTPUT_PATH }, {
	stdio = "inherit",
})
if not format.ok then
	process.exit(format.exitcode)
end

print(`Wrote {OUTPUT_PATH} from {studioVersion}`)

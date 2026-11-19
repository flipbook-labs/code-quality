-- Reads deprecation messages from Roblox's creator-docs reference, the YAML
-- pages under content/en-us/reference/engine in the Roblox/creator-docs
-- repository. generate-roblox-api.luau fetches the pages and uses these
-- messages in the data it writes.

-- Messages from one creator-docs page. `page` is the message for the class or
-- enum itself, and `items` maps a member or item name to its message.
export type DocsMessages = {
	page: string?,
	items: { [string]: string },
}

local function empty(): DocsMessages
	return {
		page = nil,
		items = {},
	}
end

-- Turns creator-docs markup into plain text. A reference such as
-- `Class.Instance:Clone()` drops its `Class.` prefix, and the same goes for
-- `Datatype.`, `Library.`, and `Global.<group>.`. A reference written as
-- `Class.ServiceProvider:GetService()|GetService()` keeps only the text after
-- the bar, and a Markdown link keeps only its text.
local function cleanMarkup(text: string): string
	text = text:gsub("`([^`]+)`", function(reference: string): string
		local display = reference:match("|(.+)$")
		if display then
			return `\`{display}\``
		end
		local stripped = reference:gsub("^Class%.", ""):gsub("^Datatype%.", ""):gsub("^Library%.", "")
		stripped = stripped:gsub("^Global%.%w+%.", "")
		return `\`{stripped}\``
	end)
	text = text:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
	return text
end

-- Joins a YAML block scalar's lines into one line, keeping only the first
-- paragraph. Later paragraphs give background that doesn't fit in a lint
-- message.
local function firstParagraph(lines: { string }): string?
	local words: { string } = {}
	for _, line in lines do
		local trimmed = line:match("^%s*(.-)%s*$") or ""
		if trimmed == "" then
			if #words > 0 then
				break
			end
		else
			table.insert(words, trimmed)
		end
	end
	if #words == 0 then
		return nil
	end
	return cleanMarkup(table.concat(words, " "))
end

-- Reads every `deprecation_message` from a creator-docs page. The pages are
-- generated YAML in a fixed layout, so a line scanner is enough: entries start
-- with `  - name: ...`, and a message is either an inline scalar or a block
-- whose lines are indented further than its key.
local function parse(source: string): DocsMessages
	local lines = source:split("\n")
	local messages = empty()
	local currentName: string? = nil
	local index = 1
	while index <= #lines do
		local line = lines[index]
		local name = line:match("^  %- name: (.+)$")
		if name then
			currentName = name:match("^['\"]?(.-)['\"]?$")
		end

		local indent, value = line:match("^(%s*)deprecation_message:%s*(.*)$")
		if indent and value then
			local message: string? = nil
			if value == "|" or value == "|-" or value == ">" or value == ">-" then
				local block: { string } = {}
				index += 1
				while index <= #lines do
					local blockLine = lines[index]
					local blockIndent = blockLine:match("^(%s*)%S")
					if blockIndent and #blockIndent <= #indent then
						index -= 1
						break
					end
					table.insert(block, blockLine)
					index += 1
				end
				message = firstParagraph(block)
			else
				local unquoted = value:match("^'(.*)'$") or value:match('^"(.*)"$') or value
				if unquoted ~= "" then
					message = cleanMarkup(unquoted)
				end
			end

			if message then
				if #indent == 0 then
					messages.page = message
				elseif currentName then
					-- Member names are written as `Class.Member` or
					-- `Class:Member`, and enum items as the bare name.
					local member = currentName:match("[%.:]([^%.:]+)$") or currentName
					messages.items[member] = message
				end
			end
		end
		index += 1
	end
	return messages
end

return table.freeze({
	cleanMarkup = cleanMarkup,
	empty = empty,
	parse = parse,
})

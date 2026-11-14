local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

-- Picks the location to report a violation at, so `lute lint` can check it for
-- suppression comments without crashing.
--
-- Before reporting a violation, `lute lint` walks every node that encloses it
-- and reads each one's `location`. The properties and indexers inside a table
-- type have no `location`, so that walk throws, and the whole file goes
-- unlinted. The walk stops at the first node that fits inside the reported
-- location. Reporting at the outermost enclosing table type therefore keeps it
-- from ever reaching those properties.
--
-- Outside a table type, this returns `location` unchanged.
local function getReportLocation(cst: syntax.CstStatBlock, location: syntax.Span): syntax.Span
	local reportLocation = location

	query.findAllFromRoot(cst, utils.isTypeTable):forEach(function(tableType)
		if syntax.span.subsumes(tableType.location, reportLocation) then
			reportLocation = tableType.location
		end
	end)

	return reportLocation
end

return getReportLocation

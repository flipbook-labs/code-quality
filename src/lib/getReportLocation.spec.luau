local parser = require("@std/syntax/parser")
local query = require("@std/syntax/query")
local test = require("@std/test")
local utils = require("@std/syntax/utils")

local getReportLocation = require("./getReportLocation")

local function getAnyLocation(source: string)
	local cst = parser.parseBlock(source)
	local reference = query.findAllFromRoot(cst, utils.isTypeReference):filter(function(node)
		return node.name.text == "any"
	end).nodes[1]
	return cst, reference.location
end

test.suite("getReportLocation", function(suite)
	suite:case("returns the location unchanged outside a table type", function(assert)
		local cst, location = getAnyLocation("local value: any = 1")
		assert.eq(getReportLocation(cst, location), location)
	end)

	suite:case("widens to the enclosing table type", function(assert)
		local cst, location = getAnyLocation("type T = { field: any }")
		local reportLocation = getReportLocation(cst, location)
		assert.eq(reportLocation.beginColumn, 10)
		assert.eq(reportLocation.endColumn, 24)
	end)

	suite:case("widens to the outermost of nested table types", function(assert)
		local cst, location = getAnyLocation("type T = { outer: { inner: any } }")
		local reportLocation = getReportLocation(cst, location)
		assert.eq(reportLocation.beginColumn, 10)
		assert.eq(reportLocation.endColumn, 35)
	end)
end)

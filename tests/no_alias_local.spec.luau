local test = require("@std/test")

local lintSource = require("./lib/lintSource")
local rule = require("@repo/src/rules/no_alias_local")

test.suite("no_alias_local", function(suite)
	suite:case("flags copying a parameter's field into a local", function(assert)
		local source = "local function Button(props)\n\tlocal text = props.text\n\treturn text\nend"
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("flags a two-field chain off a parameter", function(assert)
		local source = "local function Button(props)\n\tlocal color = props.theme.color\n\treturn color\nend"
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("flags parameters of anonymous functions", function(assert)
		local source = "return function(props)\n\tlocal text = props.text\n\treturn text\nend"
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("flags each alias in a multiple assignment", function(assert)
		local source = "local function f(props)\n\tlocal a, b = props.a, props.b\n\treturn a, b\nend"
		assert.eq(#lintSource(rule, source), 2)
	end)

	suite:case("leaves chains of three or more fields alone", function(assert)
		local source = "local function f(props)\n\tlocal x = props.a.b.c\n\treturn x\nend"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves package aliases alone", function(assert)
		local source = 'local React = require("React")\nlocal useState = React.useState'
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves a package alias from a parameter alone", function(assert)
		local source = "local function render(packages)\n\tlocal Fusion = packages.Fusion\n\treturn Fusion\nend"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves locals that capture a method call alone", function(assert)
		local source = "local function f(text)\n\tlocal trimmed = text:gsub('%s', '')\n\treturn trimmed\nend"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves a local that gets reassigned alone", function(assert)
		local source =
			"local function f(props)\n\tlocal size = props.size\n\tif not size then\n\t\tsize = 10\n\tend\n\treturn size\nend"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves a local that keeps a field's earlier value alone", function(assert)
		local source =
			"local function swap(props, nextValue)\n\tlocal old = props.value\n\tprops.value = nextValue\n\treturn old\nend"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves a local alone when a field it sits in is assigned", function(assert)
		local source =
			"local function f(props)\n\tlocal size = props.style.size\n\tprops.style = {}\n\treturn size\nend"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("leaves a local alone when the parameter is reassigned", function(assert)
		local source = "local function f(props)\n\tlocal text = props.text\n\tprops = defaults\n\treturn text\nend"
		assert.eq(#lintSource(rule, source), 0)
	end)

	suite:case("still flags a local when an unrelated field is assigned", function(assert)
		local source = "local function f(props)\n\tlocal text = props.text\n\tprops.size = 10\n\treturn text\nend"
		assert.eq(#lintSource(rule, source), 1)
	end)

	suite:case("leaves the parameter itself alone", function(assert)
		local source = "local function f(props)\n\tlocal copy = props\n\treturn copy\nend"
		assert.eq(#lintSource(rule, source), 0)
	end)
end)

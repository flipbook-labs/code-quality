local syntax = require("@std/syntax")

-- Tracks which names are in scope at each point of a file, as Selene's
-- ScopeManager does, so the lints that depend on scope flag what Selene flags.
--
-- Two kinds of binding are in scope: `local` declarations, and the bindings
-- Selene creates when a name is assigned without being declared. Those are
-- called "hoisted" here. The first such assignment in a scope makes the name
-- visible from there on, so later uses resolve to it and are not reported as
-- unscoped.

export type Declaration = {
	name: string,
	location: syntax.Span,
	-- The location of the binding this one hides, when the same name is
	-- already in scope.
	shadowsLocation: syntax.Span?,
}

export type GlobalReference = {
	name: string,
	location: syntax.Span,
	-- Whether the reference reads the name. A plain `name = value` only writes.
	read: boolean,
	-- "assign" for `name = value`, and "extend" for the base of a function
	-- declaration such as `function name.field()`.
	write: ("assign" | "extend")?,
	-- Whether the name refers to a binding that is in scope at this point.
	-- Reads that come before the binding is created are resolved too.
	resolved: boolean,
	-- The first field read directly from the name, as in `name.field` or
	-- `name["field"]`. Nil when there is none, or when the reference is part of
	-- a chain that is called, as in `name.run()`.
	firstIndex: string?,
}

export type Analysis = {
	declarations: { Declaration },
	globals: { GlobalReference },
}

type Binding = {
	name: string,
	location: syntax.Span,
}

type Scope = {
	bindings: { Binding },
}

local function staticKey(index: syntax.CstExpr): string?
	if index.tag == "string" then
		return index.value.text
	end
	return nil
end

-- Walks a whole file and returns its declarations and the references to
-- names that aren't locals. Locals are never returned as references.
local function analyze(cst: syntax.CstStatBlock): Analysis
	local scopes: { Scope } = { { bindings = {} :: { Binding } } }
	local declarations: { Declaration } = {}
	local globals: { GlobalReference } = {}

	local function pushScope()
		table.insert(scopes, { bindings = {} :: { Binding } })
	end

	local function popScope()
		table.remove(scopes)
	end

	local function findBinding(name: string): Binding?
		for scopeIndex = #scopes, 1, -1 do
			local bindings = scopes[scopeIndex].bindings
			for bindingIndex = #bindings, 1, -1 do
				if bindings[bindingIndex].name == name then
					return bindings[bindingIndex]
				end
			end
		end
		return nil
	end

	local function declare(name: string, location: syntax.Span)
		local previous = findBinding(name)
		table.insert(declarations, {
			name = name,
			location = location,
			shadowsLocation = if previous then previous.location else nil,
		})
		table.insert(scopes[#scopes].bindings, { name = name, location = location })
	end

	local function addGlobal(
		name: string,
		location: syntax.Span,
		read: boolean,
		write: ("assign" | "extend")?,
		firstIndex: string?
	)
		table.insert(globals, {
			name = name,
			location = location,
			read = read,
			write = write,
			resolved = findBinding(name) ~= nil,
			firstIndex = firstIndex,
		})
	end

	-- Selene makes an unscoped assignment visible from here on, and resolves
	-- every earlier read of the name, even one in another scope.
	local function hoistGlobal(name: string, location: syntax.Span)
		if findBinding(name) then
			return
		end

		table.insert(scopes[#scopes].bindings, { name = name, location = location })

		for _, reference in globals do
			if reference.read and reference.name == name then
				reference.resolved = true
			end
		end
	end

	local walkExpr: (expr: syntax.CstExpr, underCall: boolean) -> ()
	local walkStatement: (stat: syntax.CstStat) -> ()
	local walkStatements: (block: syntax.CstStatBlock) -> ()
	local walkBlock: (block: syntax.CstStatBlock) -> ()
	local walkFunction: (func: syntax.CstExprFunction, selfLocation: syntax.Span?) -> ()

	-- `underCall` is true when the expression is the function of a call. Selene
	-- records no indexing for those, so the first field isn't kept.
	local function walkChainBase(base: syntax.CstExpr, firstIndex: string?, underCall: boolean)
		if base.tag == "global" then
			addGlobal(base.name.text, base.name.location, true, nil, if underCall then nil else firstIndex)
		else
			walkExpr(base, underCall)
		end
	end

	local function walkConditionBranch(conditionLocal: syntax.CstLocal?, block: syntax.CstStatBlock)
		pushScope()
		if conditionLocal then
			declare(conditionLocal.name.text, conditionLocal.name.location)
		end
		walkStatements(block)
		popScope()
	end

	walkExpr = function(expr: syntax.CstExpr, underCall: boolean)
		if expr.tag == "group" then
			walkExpr(expr.expression, false)
		elseif expr.tag == "global" then
			addGlobal(expr.name.text, expr.name.location, true, nil, nil)
		elseif expr.tag == "indexname" then
			walkChainBase(expr.expression, expr.index.text, underCall)
		elseif expr.tag == "index" then
			walkChainBase(expr.expression, staticKey(expr.index), underCall)
			walkExpr(expr.index, false)
		elseif expr.tag == "call" then
			walkExpr(expr.func, true)
			for _, argument in expr.arguments do
				walkExpr(argument, false)
			end
		elseif expr.tag == "instantiate" then
			walkExpr(expr.expr, underCall)
		elseif expr.tag == "function" then
			walkFunction(expr, nil)
		elseif expr.tag == "table" then
			for _, item in expr.entries do
				if item.kind == "general" then
					walkExpr(item.key, false)
				end
				walkExpr(item.value, false)
			end
		elseif expr.tag == "unary" or expr.tag == "cast" then
			walkExpr(expr.operand, false)
		elseif expr.tag == "binary" then
			walkExpr(expr.lhsOperand, false)
			walkExpr(expr.rhsOperand, false)
		elseif expr.tag == "interpolatedstring" then
			for _, inner in expr.expressions do
				walkExpr(inner, false)
			end
		elseif expr.tag == "conditional" then
			walkExpr(expr.condition, false)
			pushScope()
			if expr.conditionLocal then
				declare(expr.conditionLocal.name.text, expr.conditionLocal.name.location)
			end
			walkExpr(expr.thenExpr, false)
			popScope()
			for _, branch in expr.elseifs do
				walkExpr(branch.condition, false)
				pushScope()
				if branch.conditionLocal then
					declare(branch.conditionLocal.name.text, branch.conditionLocal.name.location)
				end
				walkExpr(branch.thenExpr, false)
				popScope()
			end
			walkExpr(expr.elseExpr, false)
		end
	end

	walkFunction = function(func: syntax.CstExprFunction, selfLocation: syntax.Span?)
		pushScope()
		if selfLocation then
			declare("self", selfLocation)
		end
		for _, parameter in func.parameters do
			declare(parameter.name.text, parameter.name.location)
		end
		walkStatements(func.body)
		popScope()
	end

	walkBlock = function(block: syntax.CstStatBlock)
		pushScope()
		walkStatements(block)
		popScope()
	end

	walkStatements = function(block: syntax.CstStatBlock)
		for _, stat in block.statements do
			walkStatement(stat)
		end
	end

	walkStatement = function(stat: syntax.CstStat)
		if stat.tag == "do" then
			walkBlock(stat.body)
		elseif stat.tag == "conditional" then
			walkExpr(stat.condition, false)
			walkConditionBranch(stat.conditionLocal, stat.thenBlock)
			for _, branch in stat.elseifs do
				walkExpr(branch.condition, false)
				walkConditionBranch(branch.conditionLocal, branch.thenBlock)
			end
			if stat.elseBlock then
				walkBlock(stat.elseBlock)
			end
		elseif stat.tag == "while" then
			walkExpr(stat.condition, false)
			walkBlock(stat.body)
		elseif stat.tag == "repeat" then
			-- `until` can see the locals declared in the body.
			pushScope()
			walkStatements(stat.body)
			walkExpr(stat.condition, false)
			popScope()
		elseif stat.tag == "return" then
			for _, value in stat.expressions do
				walkExpr(value, false)
			end
		elseif stat.tag == "expression" then
			walkExpr(stat.expression, false)
		elseif stat.tag == "local" or stat.tag == "const" then
			-- Values are read before any of the names exist.
			for _, value in stat.values do
				walkExpr(value, false)
			end
			for _, variable in stat.variables do
				declare(variable.name.text, variable.name.location)
			end
		elseif stat.tag == "for" then
			walkExpr(stat.from, false)
			walkExpr(stat.to, false)
			if stat.step then
				walkExpr(stat.step, false)
			end
			pushScope()
			declare(stat.variable.name.text, stat.variable.name.location)
			walkBlock(stat.body)
			popScope()
		elseif stat.tag == "forin" then
			for _, value in stat.values do
				walkExpr(value, false)
			end
			pushScope()
			for _, variable in stat.variables do
				declare(variable.name.text, variable.name.location)
			end
			walkBlock(stat.body)
			popScope()
		elseif stat.tag == "assign" then
			for index, variable in stat.variables do
				local value = stat.values[index]
				if value then
					walkExpr(value, false)
				end
				if variable.tag == "global" then
					addGlobal(variable.name.text, variable.name.location, false, "assign", nil)
					hoistGlobal(variable.name.text, variable.name.location)
				else
					walkExpr(variable, false)
				end
			end
			for index = #stat.variables + 1, #stat.values do
				walkExpr(stat.values[index], false)
			end
		elseif stat.tag == "compoundassign" then
			walkExpr(stat.variable, false)
			walkExpr(stat.value, false)
		elseif stat.tag == "function" then
			local selfLocation: syntax.Span? = nil
			if stat.name.tag == "global" then
				addGlobal(stat.name.name.text, stat.name.name.location, true, nil, nil)
				hoistGlobal(stat.name.name.text, stat.name.name.location)
			elseif stat.name.tag == "indexname" then
				if stat.name.accessor.text == ":" then
					selfLocation = stat.name.indexLocation
				end
				local root = stat.name.expression
				while root.tag == "indexname" do
					root = root.expression
				end
				if root.tag == "global" then
					addGlobal(root.name.text, root.name.location, true, "extend", nil)
				end
			end
			walkFunction(stat.func, selfLocation)
		elseif stat.tag == "localfunction" then
			declare(stat.name.name.text, stat.name.name.location)
			walkFunction(stat.func, nil)
		elseif stat.tag == "typefunction" then
			walkFunction(stat.body, nil)
		end
	end

	walkStatements(cst)

	return {
		declarations = declarations,
		globals = globals,
	}
end

return analyze

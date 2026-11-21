local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local rulesPath = require("./rulesPath")

export type Options = {
	-- A rule file, or a folder of rules, to run alongside Lute's own.
	-- Defaults to every CodeQuality rule.
	rules: string?,
	-- Whether findings fail the call. Defaults to true. A repo that doesn't
	-- pass every rule yet can turn this off to print findings as warnings.
	blocking: boolean?,
}

type LintReport = {
	items: {
		{
			uri: string,
			items: {
				{
					code: string?,
					message: string,
					range: { start: { line: number, character: number } },
				}
			},
		}
	},
}

-- Lints `paths` with `lute lint` and the CodeQuality rules, and prints each
-- finding. With `blocking` on, any finding errors. With it off, this returns
-- how many findings there were.
--
-- `lute lint` exits cleanly even when a rule throws or a file can't be
-- parsed. It only prints an error and moves on. So the findings go to a JSON
-- report instead of the terminal, and anything `lute lint` still prints means
-- it failed, which errors here whether or not `blocking` is on. Files are
-- linted one at a time because Lute's parallel linting can crash at random
-- (#27). The report's name includes this process's id and a count of the
-- calls in it, so lint runs that happen at the same time can't overwrite each
-- other's report.
local callCount = 0

local function lint(paths: { string }, options: Options?): number
	local rules = if options and options.rules then options.rules else rulesPath
	local blocking = if options and options.blocking ~= nil then options.blocking else true

	callCount += 1
	local reportName = `code-quality-lint-{process.pid()}-{callCount}.json`
	local reportPath = path.format(path.join(system.tmpdir(), reportName))
	local command = {
		path.format(process.execPath()),
		"lint",
		"--sequential",
		"--json",
		"--output",
		reportPath,
		"--rules",
		rules,
	}
	table.move(paths, 1, #paths, #command + 1, command)

	local result = process.run(command)
	local output = result.stdout .. result.stderr
	if not result.ok or output:find("%S") then
		if fs.exists(reportPath) then
			fs.remove(reportPath)
		end
		error(`lute lint failed:\n{output}`, 2)
	end

	local report = json.deserialize(fs.readFileToString(reportPath)) :: LintReport
	fs.remove(reportPath)

	local findingCount = 0
	for _, file in report.items do
		for _, finding in file.items do
			findingCount += 1
			local start = finding.range.start
			print(`{file.uri}:{start.line + 1}:{start.character + 1}: [{finding.code or "lint"}] {finding.message}`)
		end
	end

	if findingCount > 0 then
		if blocking then
			error(`lute lint reported {findingCount} finding(s)`, 2)
		end
		print(`[warn] lute lint reported {findingCount} finding(s)`)
	end

	return findingCount
end

return lint

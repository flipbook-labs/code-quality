-- Names for the lint and style rules in `src/rules`. Each value is the name
-- the rule reports under, which is also the name `-- lute-lint-ignore(...)`
-- comments and the `ruleconfigs` in `.config.luau` use.
export type Rule =
	"annotate_nil_local"
	| "bad_string_escape"
	| "compare_nan"
	| "deprecated"
	| "empty_loop"
	| "explicit_instantiation"
	| "function_type_param_names"
	| "global_usage"
	| "high_cyclomatic_complexity"
	| "if_same_then_else"
	| "ifs_same_cond"
	| "inline_table"
	| "manual_table_clone"
	| "mixed_table"
	| "multiple_statements"
	| "must_use"
	| "no_alias_local"
	| "no_any"
	| "no_error_field"
	| "no_manifest_function"
	| "no_paren_truncation"
	| "no_tonumber_cast"
	| "prefer_annotation"
	| "prefer_block_comment"
	| "prefer_generic_iteration"
	| "redundant_path_conversion"
	| "restricted_module_paths"
	| "roblox_incorrect_color3_new_bounds"
	| "roblox_manual_fromscale_or_fromoffset"
	| "roblox_suspicious_udim2_new"
	| "shadowing"
	| "string_method_call"
	| "string_union_enum"
	| "suspicious_reverse_loop"
	| "tostring_in_interpolation"
	| "unbalanced_assignments"
	| "unscoped_variables"

local Rule = table.freeze({
	AnnotateNilLocal = "annotate_nil_local" :: "annotate_nil_local",
	BadStringEscape = "bad_string_escape" :: "bad_string_escape",
	CompareNan = "compare_nan" :: "compare_nan",
	Deprecated = "deprecated" :: "deprecated",
	EmptyLoop = "empty_loop" :: "empty_loop",
	ExplicitInstantiation = "explicit_instantiation" :: "explicit_instantiation",
	FunctionTypeParamNames = "function_type_param_names" :: "function_type_param_names",
	GlobalUsage = "global_usage" :: "global_usage",
	HighCyclomaticComplexity = "high_cyclomatic_complexity" :: "high_cyclomatic_complexity",
	IfSameThenElse = "if_same_then_else" :: "if_same_then_else",
	IfsSameCond = "ifs_same_cond" :: "ifs_same_cond",
	InlineTable = "inline_table" :: "inline_table",
	ManualTableClone = "manual_table_clone" :: "manual_table_clone",
	MixedTable = "mixed_table" :: "mixed_table",
	MultipleStatements = "multiple_statements" :: "multiple_statements",
	MustUse = "must_use" :: "must_use",
	NoAliasLocal = "no_alias_local" :: "no_alias_local",
	NoAny = "no_any" :: "no_any",
	NoErrorField = "no_error_field" :: "no_error_field",
	NoManifestFunction = "no_manifest_function" :: "no_manifest_function",
	NoParenTruncation = "no_paren_truncation" :: "no_paren_truncation",
	NoTonumberCast = "no_tonumber_cast" :: "no_tonumber_cast",
	PreferAnnotation = "prefer_annotation" :: "prefer_annotation",
	PreferBlockComment = "prefer_block_comment" :: "prefer_block_comment",
	PreferGenericIteration = "prefer_generic_iteration" :: "prefer_generic_iteration",
	RedundantPathConversion = "redundant_path_conversion" :: "redundant_path_conversion",
	RestrictedModulePaths = "restricted_module_paths" :: "restricted_module_paths",
	RobloxIncorrectColor3NewBounds = "roblox_incorrect_color3_new_bounds" :: "roblox_incorrect_color3_new_bounds",
	RobloxManualFromscaleOrFromoffset = "roblox_manual_fromscale_or_fromoffset" :: "roblox_manual_fromscale_or_fromoffset",
	RobloxSuspiciousUdim2New = "roblox_suspicious_udim2_new" :: "roblox_suspicious_udim2_new",
	Shadowing = "shadowing" :: "shadowing",
	StringMethodCall = "string_method_call" :: "string_method_call",
	StringUnionEnum = "string_union_enum" :: "string_union_enum",
	SuspiciousReverseLoop = "suspicious_reverse_loop" :: "suspicious_reverse_loop",
	TostringInInterpolation = "tostring_in_interpolation" :: "tostring_in_interpolation",
	UnbalancedAssignments = "unbalanced_assignments" :: "unbalanced_assignments",
	UnscopedVariables = "unscoped_variables" :: "unscoped_variables",
})

return Rule

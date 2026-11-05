# Cmder interface redesign

This spec implements the six improvements approved on 2026-11-05. Breaking changes are intentional; publishing is outside this task.

## Execution and errors

- Command and root callbacks have type `(Context) -> Unit raise`. Their original business errors propagate through dispatch and run without conversion to CliError or text.
- `cli` supports root options, positionals, examples, callback and subcommands. Only the selected callback runs.
- `parse` has explicit argv, no I/O or execution, and always checks declared integer inputs in selected scopes after structural parsing. Help/version retain parser precedence.
- `get_int` returns None only for an absent declared text argument and raises InvalidInteger/IntegerOutOfRange otherwise; no legacy length cap remains. Raising getters reject unknown/out-of-scope names and Boolean/text mismatches. Checked Boolean/text/collection getters supplement the compatible non-raising getters. Raw integer text and string/positional-to-integer conversion remain supported.
- `run_or_exit` provides default error reporting and exit status one for standalone tools; `run` and dispatch preserve original business errors for custom hosts. The version default remains `0.0.0` and the existing `commands`/`subcommands` labels are retained.
- Optional labelled arguments use direct values: `default=3`, `run=fn(ctx) { ... }`, `app.run(argv=[...])`.

## Definitions and scopes

- Option definitions are helper-constructed, immutable and carry a typed kind: string default String?, integer default Int32?, or Boolean flag. Short names are Char?. Defaults normalize effective required to false; Boolean flags are optional, initially false.
- Command collections are copied into ReadOnlyArray. CliApp owns a single root CommandDef and version. External collection mutation cannot alter the application.
- `cli` validates the entire definition tree during construction and raises InvalidDefinition for invalid names, duplicate names/short spellings, invalid positional ordering, or descendant conflicts with inherited global names/shorts. Sibling local names may repeat.
- Application/subcommand names are single words with ASCII letters/digits/underscores/hyphens/dots/plus signs or printable non-ASCII characters, without whitespace, controls or leading hyphens. Option/positional identifiers use ASCII letters/digits/underscores/hyphens without a leading hyphen. Short spellings are ASCII letters/digits/underscores. Completion function identifiers encode application names injectively, independently of shell command spellings. Descriptions remain unrestricted text and are encoded for each shell's quoting and completion grammar.
- Required positionals cannot coexist with subcommands, because argparse makes those descendants unreachable; reject the combination in every scope. Optional positionals can coexist, but positional consumption prevents later selection of a subcommand.
- The final positional remains unbounded by default. `multiple=false` limits it to one value. Earlier positionals always accept at most one value. Parsing, overrides and schema use the same effective cardinality rule. A later subcommand name after positional input is a parse error unless escaped with `--`.
- Only `global=true` options are shared with descendants and accepted before/after a subcommand. Other options and positionals remain local to the declaring command.
- A selected invocation exposes only its selected command's locals and inherited globals. Explicit ancestor-local options return UnexpectedLocalArgument before cmder required/type validation instead of being silently dropped; ancestor-local defaults remain invisible. Each global has one canonical definition; descendants cannot redefine it.
- Local required options constrain only their owning command when selected. Required globals constrain their entire declaring subtree. Missing required local/global options return Failed(MissingOption(name)); missing required positionals return MissingPositional(name). Help/version and structural parser errors retain precedence. Explicit build_command interop retains argparse's own required semantics and its target's explicit examples.
- Help and error Usage retain required annotations for their target command. Commands with children and required locals include an explicit help notice naming those locals and explaining that their requirement applies only to the command's own execution. `required_scope_notice` replaces it for localization; an empty string disables it. Examples/notices never appear in parent command lists. Schema examples include required ancestor globals and selected-command locals, excluding ancestor locals, even for argument-free leaves. Root-local required values remain in root examples.
- Integer options accept separated negative numeric spellings without consuming following flags or the `--` separator. An actual builtin help request following a pending integer displays help; application-defined help spellings retain their own semantics. Original argv and integer spellings are preserved.
- Defaults apply only when that argument has no explicit value. The same definitions drive parsing, help, schema and completion. Schema defaults use their JSON types and include global metadata and root positionals/examples.

## Invocation and host overrides

- Invocation exposes a read-only command path and Context; all Context storage is private and returned value collections are copies/read-only.
- Invocation binds the selected command snapshot. `call.dispatch()` executes that callback without resolving against another application, reparsing or implicit I/O. Repeated calls execute again.
- Dispatch of a root without callback raises MissingCommand; selected groups/leaves without callbacks raise the appropriate MissingSubcommand/MissingHandler error.
- `with_overrides` accepts typed text/integer/flag/positional values, checks visible names, kinds and positional cardinality, then returns a fresh invocation atomically. Failed overrides preserve the original result.
- Changed values have Override provenance; unchanged sources remain intact. Original raw argv spellings survive normal parsing. No stale provenance can be created by direct mutation.
- Context no longer carries the unused subcommand tree. Selected path belongs to Invocation.

## Acceptance evidence

Generated Bash scripts preserve the shell's default filename fallback when no
command or option matches. Generated Zsh scripts complete positional filenames,
pending option values and literal filenames after `--`; value options accept
separate words, `--name=value` and `-nvalue`. Fish retains native filename
completion. No application-specific value list or validation is inferred.
Shell regression evidence includes real Readline/ZLE Tab completion in bounded,
owned PTY sessions as well as the existing scope and escaping probes.

Tests cover original business error propagation through run/dispatch, roots and nested callbacks, integer absence/format/overflow/padding, global scope and argument placement, local isolation, definition rejection, alias safety, bound repeated dispatch, valid/invalid atomic overrides and provenance, root schema/help/completion, and process exit/output behavior on native/JS/wasm-gc.

English/Chinese README and executable examples demonstrate the new interfaces and contain a migration guide. `nu scripts/check-readme.nu` compares bilingual code blocks/metadata, compiles the actual marked MoonBit snippets against the current worktree with warnings denied, and runs all snippets on native/JS/wasm-gc, including the Quick Start error exit. Stable named HTML markers declare snippet kind/bindings/context; snippet order is not an identifier, and contexts reuse actual document snippets rather than a second copy. CI and `just docs` run this check. Generated interfaces are regenerated by MoonBit. Independent Standards and Spec review must have no unresolved actionable findings before commit.

## 0.6 review corrections

The 0.6 changes above deliberately supersede the 0.5.1 ancestor-input and error-shape policies. Bilingual migration guides distinguish released v0.3.0 APIs from later unreleased development interfaces. CHANGELOG records all changed error variants. README checks use an owned temporary copy of the current module outside the source tree; process-check counts follow their actual case lists. Existing reserved Env provenance and the parse/dispatch validation stages remain intentional.

Until argparse exposes separate required-validation and help-context policies, cmder matches only complete help generated by the same parser to restore annotations and append target-specific sections. Synthetic help paths preserve inherited argument ordering without re-parsing caller argv. Diagnostic categories are never inferred from message wording; unfamiliar upstream output is preserved without aborting. Help adaptation must retain duplicate-option and short-cluster structural errors that precede the help request.

# cmder

[English](README.md) | [简体中文](README.zh.md)

`hustcer/cmder` is a declarative CLI builder for MoonBit, built on `moonbitlang/core/argparse`.

**This project is a fork of [mizchi/admiral](https://github.com/mizchi/admiral), modified and maintained on top of its implementation.** Thanks to mizchi and the upstream contributors for the original design and implementation. The upstream project was inspired by [gunshi](https://github.com/kazupon/gunshi).

- Executable root commands and nested subcommands with raising callbacks.
- String, Boolean and checked Int32 options, plus positional arguments.
- Explicit global options shared with descendants; other arguments stay local.
- Immutable command definitions and parsed invocations with value provenance.
- Help, version, JSON definitions and Bash/Zsh/Fish completion scripts.

## Differences from admiral 0.1.2

Since the fork, cmder has changed its package name and API. Migration requires updating imports and adapting code to the current interfaces:

- Option helpers accept direct values for `short` and `default`, and definitions and contexts are read-only.
- Root commands can have callbacks and positional arguments. Callbacks can propagate errors to the application.
- Options are local by default; set `global=true` to make an option available to descendant commands. Required local options apply only to the selected command.
- `parse` returns structured outcomes without executing callbacks or performing process I/O. A parsed invocation can be inspected, overridden and dispatched; argument provenance is available through `source_of`.
- Command definitions are validated at construction, and integer options are checked for syntax and Int32 range during parsing.
- JSON definitions include positional order and cardinality; generated help and shell completions reflect command and option scopes.

See the sections below for current usage and [CHANGELOG.md](CHANGELOG.md) for version-specific changes.

## Installation

```sh
moon add hustcer/cmder
```

Add the library to the consuming package's `moon.pkg`:

```text
import {
  "hustcer/cmder",
}
pkgtype(kind: "executable")
```

## Quick Start

A single-command tool does not need an artificial subcommand. Put this in `main.mbt`:

<!-- cmder-example {"id":"quick-start","kind":"program","args":["-n","Ada"],"stdout":"Hello, Ada!\n","fail_args":["-n","Ada","--count","bad"],"error":"invalid integer for 'count': 'bad'"} -->

```moonbit
///|
fn main raise {
  let app = @cmder.cli(
    name="hello",
    version="1.0.0",
    options=[
      @cmder.string("name", short='n', required=true),
      @cmder.int("count", short='c', default=1),
      @cmder.bool("loud", short='l'),
    ],
    examples=["hello -n Alice", "hello -n Bob -l -c 2"],
    run=ctx => {
      let name = ctx.get_string_required("name")
      let count = ctx.get_int_required("count")
      for _ in 0..<count {
        let message = "Hello, \{name}!"
        println(if ctx.get_bool("loud") { message.to_upper() } else { message })
      }
    },
  )
  app.run_or_exit()
}
```

```text
$ hello -n Alice
Hello, Alice!
$ hello -n Bob -l -c 2
HELLO, BOB!
HELLO, BOB!
```

`--help` and `--version` are generated automatically. Application callbacks have type `(Context) -> Unit raise`: checked getter errors and business errors propagate unchanged through dispatch and run. `run_or_exit` reports errors and exits one; help/version exit zero. Hosts that need custom reporting use `run` or `parse`. Error output uses stderr on native and JS; the current wasm-gc runtime falls back to stdout.

`cli` validates the entire definition tree during construction and raises `CliError::InvalidDefinition` for invalid names, duplicate arguments/short flags/subcommands, positional ordering errors, and conflicts with inherited global arguments. This is why the example uses `fn main raise`.

Application and subcommand names are single words using ASCII letters, digits, underscores, hyphens, dots, plus signs or printable non-ASCII characters; whitespace, control characters and leading hyphens are rejected. Names such as `tool.exe`, `中文工具` and `release.v2+` are valid. Option and positional identifiers use ASCII letters, digits, underscores and hyphens, without a leading hyphen. Short options use one ASCII letter, digit or underscore. Completion function identifiers are encoded independently of command spellings; descriptions remain unrestricted text.

## Options and Positional Arguments

<!-- cmder-example {"id":"options","kind":"pure","binds":["options"]} -->

```moonbit
let options = [
  @cmder.string("config", short='f', required=true),
  @cmder.string("host", default="localhost"),
  @cmder.int("port", short='p', default=3000),
  @cmder.bool("verbose", short='v', global=true),
]
```

`short` and `default` accept direct values. A string/integer default makes the option optional even with `required=true`. Boolean flags are optional and initially false. Helpers create normalized, read-only `OptionDef` values; direct record construction is not supported. `OptionKind` stores a `String?` default for `StringOpt`, an `Int32?` default for `IntOpt`, and no value default for `BoolOpt`. Missing short flags are represented by `None`.

All integer options are checked during `parse` and `run`: decimal Int32 syntax with an optional leading minus, and range -2147483648 through 2147483647. Leading zeroes have no length cap. Negative values support `--delta -1`, `-d -1` and `--delta=-1`. Integer options do not consume following flags or `--`; `--count --help` displays help. Raw spellings remain available through `get_string`. Positive-only values, product ranges and relationships remain application rules.

Root and nested commands accept `positionals`. Required positionals must precede optional ones. Each positional except the last accepts at most one value; the final positional accepts all remaining values by default. Set `multiple=false` on a positional to limit it to one value, including the final one; extra input then fails parsing:

<!-- cmder-example {"id":"positionals","kind":"raising","binds":["app"]} -->

```moonbit
let app = @cmder.cli(
  name="copy",
  positionals=[
    @cmder.positional("source", required=true),
    @cmder.positional("destinations"),
  ],
  run=ctx => {
    println(ctx.get_string_required("source"))
    println(ctx.get_strings("destinations").join(", "))
  },
)
```

`copy a.txt b.txt c.txt` binds `source="a.txt"` and `destinations=["b.txt", "c.txt"]`.

A command with subcommands may have optional positionals, but cannot have required positionals: argparse would make its subcommands unreachable, so construction rejects that combination. After positional input starts, a later subcommand name causes a parse error. Use `--` before that name to read it literally: `app x.txt -- go` treats both words as positional values.

## Subcommands and Scope

<!-- cmder-example {"id":"subcommands","kind":"raising","binds":["app"]} -->

```moonbit
let app = @cmder.cli(
  name="myapp",
  options=[@cmder.bool("verbose", short='v', global=true)],
  commands=[
    @cmder.command(
      name="db",
      options=[@cmder.string("region", default="west", global=true)],
      subcommands=[
        @cmder.command(name="migrate", options=[@cmder.bool("dry-run")], run=ctx => {
          if ctx.get_bool("verbose") {
            println("Starting migration")
          }
          println(ctx.get_string_required("region"))
          println(if ctx.get_bool("dry-run") { "Preview" } else { "Apply" })
        }),
      ],
    ),
  ],
)
```

Global options are accepted at their declaring command and anywhere below it. Both `myapp -v db migrate` and `myapp db migrate -v` work; `--region` becomes available after entering `db`. Globals have one definition and cannot be redefined or shadowed by descendant names or short flags. Explicit input takes precedence over that argument's default.

Other arguments are local. A callback sees the selected command's locals and its inherited globals. Explicit ancestor-local options followed by a subcommand fail with `UnexpectedLocalArgument`, rather than silently losing their values. Ancestor-local defaults do not leak. Local names may repeat in separate scopes without merging: a root `string("count")` never supplies a child `int("count")`. Mark a parameter global when descendants need to read it.

Local `required=true` options are required only when their owning command is selected. A root-local required `token` does not block `myapp db migrate`. A required global is required throughout its declaring subtree and stays readable in descendant callbacks. Missing local/global required options return `Failed(CliError::MissingOption(name))`; missing required positionals return `MissingPositional(name)`. Help and error Usage retain required annotations. Help names required locals and explains their scope when subcommands exist; `required_scope_notice="..."` on `cli` or `command` replaces this notice for localization, and an empty string disables it. Examples and notices appear only in their own command's help, outside parent command lists. Generated examples include required ancestor globals, even for leaves without local arguments.

Only the selected callback runs. Selecting a group with a callback executes that callback; selecting a deeper command executes only the deeper callback. Without a callback, dispatch raises `MissingCommand` for the root, `MissingSubcommand` for a group, or `MissingHandler` for a leaf.

## Reading Arguments and Errors

| Method                      | Result                         | Meaning                                                    |
| --------------------------- | ------------------------------ | ---------------------------------------------------------- |
| `get_bool(name)`            | `Bool`                         | False when absent                                          |
| `get_string(name)`          | `String?`                      | First raw value, including integer spelling                |
| `get_string_required(name)` | `String raise CliError`        | Missing values raise `MissingOption` / `MissingPositional` |
| `get_int(name)`             | `Int32? raise CliError`        | None only for absence; format/range errors raise           |
| `get_int_required(name)`    | `Int32 raise CliError`         | Missing, malformed and overflow values raise               |
| `get_strings(name)`         | `Array[String]`                | Fresh copy of all values; empty when absent                |
| `get_bool_checked(name)`    | `Bool raise CliError`          | Declared Boolean flag; false when absent                   |
| `get_string_checked(name)`  | `String? raise CliError`       | Declared text argument; None when absent                   |
| `get_strings_checked(name)` | `Array[String] raise CliError` | Declared text argument; fresh value copy                   |
| `source_of(name)`           | `ValueSource?`                 | Effective provenance, or None when absent                  |

Raising getters validate visible names: misspellings and out-of-scope names raise `UnknownArgument`, and incompatible Boolean/text reads raise `ArgumentTypeMismatch`. The three non-raising getters retain their loose missing-name behavior for compatibility. Text getters accept strings, raw integers and positionals. `get_int` and `get_int_required` also accept string/positional text and share one conversion rule: invalid syntax raises `InvalidInteger(name, raw)`; overflow raises `IntegerOutOfRange(name, raw)`. Only an absent declared value returns None. Required getters distinguish `MissingOption` from `MissingPositional`.

`CliError::message()` and `to_string()` produce display-ready diagnostics. `ParseError(message)` preserves argparse's diagnostic text and help; do not parse it for machine-readable categories. Business callback errors keep their original error type and can be handled centrally by the host.

## Parsing, Host Checks and Dispatch

`parse` requires explicit argv without the executable name. It performs no process I/O, reads no process environment, and invokes no callbacks. It returns `Parsed`, `Help`, `Version` or `Failed`. Help/version and structural parser errors keep argparse's precedence over integer checks; only selected scopes undergo input type checks.

Place this flow in a raising host function. Import `moonbitlang/core/env` when the host controls process exit, as below; `run_or_exit` provides default reporting for standalone tools.

<!-- cmder-example {"id":"host-dispatch","kind":"raising","stdout":"3\n"} -->

```moonbit
let app = @cmder.cli(name="app", options=[@cmder.int("count", default=1)], run=ctx => {
  println(ctx.get_int_required("count"))
})
match app.parse(argv=["--count", "2"]) {
  Parsed(call) => {
    // Perform host checks before execution.
    let edited = call.with_overrides({
      "count": @cmder.ArgumentValue::Integer(3),
    })
    edited.dispatch()
  }
  Help(text) | Version(text) => println(text)
  Failed(error) => {
    eprintln(error.message())
    @env.exit(1)
  }
}
```

A parsed invocation binds the selected command snapshot. `call.dispatch()` needs no app pairing, does not reparse or perform help/version I/O, and propagates original callback errors. Each call executes again. `command_path` is a read-only list excluding the application name; an empty path selects the root. `Context` has private storage and exposes no subcommand tree.

Definitions copy caller-owned collections into read-only arrays. Parsed results are isolated from argv edits and returned value-array edits. Host overrides are explicit and atomic: `with_overrides` checks visible names, argument kinds and positional cardinality, then returns a fresh invocation. A failed override leaves the original invocation unchanged.

| Override value                       | Accepted argument                                        |
| ------------------------------------ | -------------------------------------------------------- |
| `ArgumentValue::Text(text)`          | String option, or integer option with checked raw syntax |
| `ArgumentValue::Integer(value)`      | Integer option                                           |
| `ArgumentValue::Flag(value)`         | Boolean flag                                             |
| `ArgumentValue::Positionals(values)` | Positional argument; respects required/final cardinality |

`call.source_of(name)` and `call.context.source_of(name)` return `Argv`, `Default`, `Override` or None. `Env` is reserved for the underlying source model; current definitions do not configure environment bindings. Unchanged values preserve their sources; overridden values use `Override`, even when equal to argv. Clearing an optional positional makes it absent with no effective source. `was_provided(name)` is true only when the current effective source is `Argv`.

`app.run()` reads process argv, parses and dispatches, and prints/exits zero for help or version. `app.run(argv=[...])` uses explicit arguments. Parser and callback errors propagate to its caller. `app.run_or_exit()` additionally reports failures and exits one. Embedded hosts use `parse` and `call.dispatch()` to retain control over output and exit status. The default version string is `0.0.0`; specify `version` for a released tool.

## Exporting Definitions and Completion

<!-- cmder-example {"id":"exports","kind":"raising","context":"subcommands","binds":["schema_text","schema_json","help","bash_script","zsh_script","fish_script"]} -->

```moonbit
let schema_text = app.render_schema()
let schema_json = app.render_schema_json()
let help = app.render_help(command_path=["db", "migrate"])
let bash_script = app.render_bash_completion()
let zsh_script = app.render_zsh_completion()
let fish_script = app.render_fish_completion()
```

The CLI description format is not standard JSON Schema. It describes declarations at their owning command, including `global`, normalized `required`, typed defaults, positionals and examples. Integer defaults are JSON numbers; string defaults are JSON strings. Root positionals/examples use the same structure as nested commands. Positional metadata includes zero-based `index`, `min_args` and `max_args` (null for the final unbounded positional); consumers should sort by `index`.

Nested help and completion include inherited globals and exclude ancestor locals. Built-in help, root version and `help` topics are included; application-defined long and short spellings shadow builtins independently. Command and option suggestions stop after `--`, while the shell's filename completion remains available. Bash uses its default filename fallback when no generated candidate matches; Zsh uses `_files` for positional arguments, option values and tokens after `--`. Zsh value options support separate words, `--name=value` and `-nvalue`. Fish retains its native filename completion. Application-specific value lists are not generated; filename candidates do not imply that a value is valid for the application.

Applications own script/schema export entry points; cmder does not add `--schema` or a completion subcommand. Construct the application before handling export requests. The [executable example](src/examples/cli/main.mbt) demonstrates schema export.

```bash
source ./myapp.bash
```

```zsh
autoload -Uz compinit
compinit
source ./_myapp
```

```fish
source ./myapp.fish
```

`build_command(command)` is an explicit argparse interop escape hatch: it validates definitions and returns an `argparse.Command` with argparse's ancestor-required semantics, without cmder's selected-local required checks, integer input checks or callback execution. Normal consumers use `CliApp::parse`.

## Migration from 0.3

| Previous usage                                 | Current usage                                                   |
| ---------------------------------------------- | --------------------------------------------------------------- |
| `default=Some(3)` / `default=Some("x")`        | `default=3` / `default="x"`                                     |
| `run=Some(fn(ctx) { ... })`                    | `run=(ctx) => { ... }`; errors may propagate                    |
| `app.run(argv=Some(args))`                     | `app.run(argv=args)`                                            |
| `get_int_checked(name)`                        | `get_int(name)`; malformed input now raises                     |
| Implicit ancestor parameter inheritance        | Mark shared options `global=true`                               |
| Direct Context/path mutation                   | `call.with_overrides(...)`                                      |
| `Context.subcommand` / `get_subcommand()`      | `Invocation.command_path`                                       |
| Public definition record literals              | `cli`, `command`, `string`, `int`, `bool`, `positional` helpers |
| `app.name`, `app.commands`, `app.root_options` | `app.root.name`, `app.root.subcommands`, `app.root.options`     |

`OptionType` is replaced by `OptionKind` with typed default payloads. Definitions fail at construction rather than when the first argv is parsed. These are intentional breaking changes.

From 0.5.1 to 0.6: explicit ancestor-local options now fail instead of disappearing; use `global=true` or pass the option to its owning command. Missing global required options now use `MissingOption`, and missing required positionals use `MissingPositional`; in 0.5.1 both used `ParseError`. Raising getters reject unknown names and Boolean/text mismatches. Existing non-raising getters and the final positional's multiple-value default remain available. `multiple=false`, checked getters and `run_or_exit` are additive APIs. The unreleased post-0.3 development APIs `validate_types` and `app.dispatch(call)` were removed in 0.5; they were not part of v0.3.0.

## Local Development

```sh
moon check --deny-warn --target native
moon test --target native
moon test --target js
moon test --target wasm-gc
moon run src/examples/cli --target native -- greet -n Alice
moon run src/examples/cli --target native -- db migrate up --dry-run
moon run src/examples/cli --target native -- --schema
nu scripts/check-cli.nu
nu scripts/check-completions.nu
nu scripts/check-readme.nu
```

The process suite covers native/JS/wasm-gc. Shell regressions require Nushell 0.116+, Bash, Fish and Zsh; they execute generated scripts in clean shells, capture Zsh widget calls, and use a bounded PTY session to test actual Bash Readline and Zsh ZLE filename completion. CI runs shell checks on native. The README check compares both languages' code blocks and example metadata, compiles the actual MoonBit snippets against this worktree with warnings denied, and executes them on all three backends, including the Quick Start error exit. HTML `cmder-example` markers name each snippet, its bindings and any context snippet; keep those markers synchronized when editing examples. CI runs this check as well. See [the public interface](src/pkg.generated.mbti) and [the redesign contract](docs/superpowers/specs/2026-11-05-cmder-interface.md).

## Acknowledgments and License

Thanks to the author and contributors of [mizchi/admiral](https://github.com/mizchi/admiral). This package is a fork of that repository, with further modifications built on its implementation. Thanks also to [gunshi](https://github.com/kazupon/gunshi) for the design inspiration, and to MoonBit's `core/argparse` for argument parsing.

License: MIT, as declared in [moon.mod](moon.mod).

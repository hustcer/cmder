# Changelog

## 0.5.1 - 2026-11-05

### Changed

- **Breaking:** Required local options apply only when their command is selected; ancestor-local requirements no longer block descendant commands. Required global options still apply to descendants.
- Allow dots, plus signs, and printable non-ASCII characters in application and command names.

### Fixed

- Validate explicitly supplied ancestor-local integer values and align help and generated examples with option scopes.
- Avoid completion function name collisions and quote command registrations for supported names.

## 0.5.0 - 2026-11-05

### Changed

- **Breaking:** Mark options with `global=true` to share them with descendant commands; ancestor-local values are no longer merged into descendant contexts.
- **Breaking:** Pass optional helper arguments directly, use `get_int` for checked integer reads, and use `Invocation.dispatch` and `with_overrides` for host-controlled execution.
- **Breaking:** Definitions and contexts are read-only, and `cli` and `build_command` validate definitions and may raise errors. Integer options are validated during parsing.
- Allow callbacks to propagate their original errors. Parsed invocations retain the selected command and support validated, atomic overrides with value provenance.
- Support root positional arguments and align help, schema, and completions with argument scopes.
- Report failures in the executable example with a nonzero exit status.

## 0.3.0 - 2026-11-05

### Added

- Add side-effect-free parsing with structured outcomes and CLI errors, allowing hosts to handle help, version output, and failures.
- Expose argument value provenance and checked integer getters.
- Add help rendering for command paths and explicit examples.

### Fixed

- Align shell completions with built-in flags, help topics, and application-defined spellings.

## 0.2.0 - 2026-11-04

### Changed

- Renamed the MoonBit module from `mizchi/admiral` to `hustcer/cmder`; update dependency and import paths accordingly.
- Added positional argument order and cardinality metadata to the JSON schema, and included required arguments in generated examples.
- Added Chinese documentation and expanded the English API documentation.

### Fixed

- Passed ancestor option values to nested command callbacks, with the closest value taking precedence.
- Preserved trailing positional arguments and accepted separated negative integer option values.
- Corrected Bash, Zsh, and Fish completion handling for nested commands and options. Bash completion no longer depends on `bash-completion` and stops suggesting after `--`.

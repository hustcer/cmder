///|
#derive(Debug, Eq)
pub(all) enum ValueSource {
  Argv
  Env
  Default
  Override
}

///|
pub extend ValueSource with Debug::{to_repr}

///|
pub extend ValueSource with Eq::{equal, not_equal}

///|
/// Host-supplied values. Text can also supply a checked raw integer spelling.
/// Positionals accepts a read-only list; with_overrides copies its contents.
pub(all) enum ArgumentValue {
  Text(String)
  Integer(Int32)
  Flag(Bool)
  Positionals(ReadOnlyArray[String])
}

///|
priv enum ArgumentSpec {
  Option(OptionDef)
  Positional(PositionalDef, multiple~ : Bool)
}

///|
/// Immutable result bound to the selected command snapshot. Context contains
/// only the selected command's locals and inherited globals. Raw argv spelling
/// and effective value provenance are preserved. Use with_overrides for edits.
pub struct Invocation {
  command_path : ReadOnlyArray[String]
  context : Context
  priv selected : CommandDef
  priv specs : Map[String, ArgumentSpec]
}

///|
pub(all) enum ParseOutcome {
  Parsed(Invocation)
  Help(String)
  Version(String)
  Failed(CliError)
}

///|
/// Returns the effective source, or None for an absent value.
pub fn Invocation::source_of(self : Invocation, name : String) -> ValueSource? {
  self.context.source_of(name)
}

///|
/// True when the current effective value came from argv. Host overrides use
/// Override provenance, even when their value equals the original argv value.
pub fn Invocation::was_provided(self : Invocation, name : String) -> Bool {
  self.source_of(name) is Some(Argv)
}

///|
fn validate_scope_types(
  cmd : CommandDef,
  matches : @argparse.Matches,
) -> Unit raise CliError {
  for option in cmd.options {
    if option.kind is IntOpt(_) {
      for value in matches.values.get(option.name).unwrap_or([]) {
        ignore(parse_integer_value(option.name, value))
      }
    }
  }
}

///|
fn invocation_from_matches(
  app : CliApp,
  matches : @argparse.Matches,
) -> Invocation raise CliError {
  let path : Array[String] = []
  let globals : Array[OptionDef] = []
  let mut selected = app.root
  let mut current = matches
  while true {
    validate_scope_types(selected, current)
    guard current.subcommand is Some((name, child)) else { break }
    for option in selected.options {
      if option.global {
        globals.push(option)
      }
    }
    path.push(name)
    guard find_command_def(selected.subcommands, name) is Some(command) else {
      raise CliError::UnknownCommand(path)
    }
    selected = command
    current = child
  }
  let specs : Map[String, ArgumentSpec] = Map([])
  for option in globals {
    specs[option.name] = Option(option)
  }
  for option in selected.options {
    specs[option.name] = Option(option)
  }
  for index, pos in selected.positionals {
    specs[pos.name] = Positional(
      pos,
      multiple=index == selected.positionals.length() - 1,
    )
  }
  let flags : Map[String, Bool] = Map([])
  let values : Map[String, Array[String]] = Map([])
  let sources : Map[String, ValueSource] = Map([])
  for name, _ in specs {
    if current.flags.get(name) is Some(value) {
      flags[name] = value
    }
    if current.values.get(name) is Some(value) {
      values[name] = value.copy()
    }
    if current.sources.get(name) is Some(source) {
      sources[name] = match source {
        @argparse.ValueSource::Argv => Argv
        @argparse.ValueSource::Env => Env
        @argparse.ValueSource::Default => Default
      }
    }
  }
  {
    command_path: ReadOnlyArray::from_array(path),
    context: { flags, values, sources, },
    selected,
    specs,
  }
}

///|
/// Parses explicit argv without process I/O or callbacks. All declared integer
/// inputs in selected scopes are checked for signed decimal Int32 syntax and
/// overflow. Help/version and structural parser failures retain precedence.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[@cmder.int("count")])
///   assert_true(
///     app.parse(argv=["--count", "bad"])
///     is Failed(@cmder.CliError::InvalidInteger("count", "bad")),
///   )
/// }
/// ```
pub fn CliApp::parse(self : CliApp, argv~ : ArrayView[String]) -> ParseOutcome {
  match build_cli_command(self).parse_outcome(argv~) {
    Parsed(matches) =>
      Parsed(invocation_from_matches(self, matches)) catch {
        error => Failed(error)
      }
    Help(text) => Help(text)
    Version(text) => Version(text)
    Failed(error) => Failed(CliError::ParseError(error.to_string()))
  }
}

///|
/// Applies host overrides atomically and returns a fresh validated invocation.
/// Unknown names, incompatible kinds and invalid positional cardinality raise
/// CliError. Unchanged values preserve their sources; changed values use Override.
/// Clearing an optional positional makes it absent, with no effective source.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[@cmder.int("count", default=1)])
///   guard app.parse(argv=[]) is Parsed(call) else { fail("parse") }
///   let edited = call.with_overrides({ "count": @cmder.ArgumentValue::Integer(3) })
///   assert_true(edited.context.get_int("count") == Some(3))
///   assert_true(call.context.get_int("count") == Some(1))
///   assert_true(edited.source_of("count") == Some(@cmder.ValueSource::Override))
/// }
/// ```
pub fn Invocation::with_overrides(
  self : Invocation,
  overrides : Map[String, ArgumentValue],
) -> Invocation raise CliError {
  let flags = self.context.flags.copy()
  let values = self.context.values.copy()
  let sources = self.context.sources.copy()
  for name, value in overrides {
    guard self.specs.get(name) is Some(spec) else {
      raise CliError::UnknownArgument(name)
    }
    match (spec, value) {
      (Option({ kind: BoolOpt, .. }), Flag(value)) => flags[name] = value
      (Option({ kind: StringOpt(_), .. }), Text(value)) =>
        values[name] = [value]
      (Option({ kind: IntOpt(_), .. }), Integer(value)) =>
        values[name] = [value.to_string()]
      (Option({ kind: IntOpt(_), .. }), Text(value)) => {
        ignore(parse_integer_value(name, value))
        values[name] = [value]
      }
      (Positional(pos, multiple~), Positionals(items)) => {
        if (pos.required && items.is_empty()) ||
          (!multiple && items.length() > 1) {
          raise CliError::InvalidOverride(
            name, "invalid number of positional values",
          )
        }
        if items.is_empty() {
          values.remove(name)
          sources.remove(name)
          continue
        }
        values[name] = items[:].to_owned()
      }
      _ =>
        raise CliError::InvalidOverride(
          name, "value does not match the argument kind",
        )
    }
    sources[name] = Override
  }
  { ..self, context: { flags, values, sources, }, }
}

///|
/// Renders root or nested help, including inherited globals and explicit
/// examples, without parsing or executing. Unknown paths raise UnknownCommand.
pub fn CliApp::render_help(
  self : CliApp,
  command_path~ : ArrayView[String] = [],
) -> String raise CliError {
  if command_path.is_empty() {
    return build_cli_command(self).render_help()
  }
  let mut selected = self.root
  let globals : Array[OptionDef] = []
  for name in command_path {
    for option in selected.options {
      if option.global {
        globals.push(option)
      }
    }
    guard find_command_def(selected.subcommands, name) is Some(command) else {
      raise CliError::UnknownCommand(command_path.to_owned())
    }
    selected = command
  }
  let options = globals + selected.options[:].to_owned()
  build_parser({
    ..selected,
    name: "\{self.root.name} \{command_path.to_owned().join(" ")}",
    options: ReadOnlyArray::from_array(options),
  }).render_help()
}

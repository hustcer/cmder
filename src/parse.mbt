///|
/// Origin of the effective argument value, matching argparse's source model.
/// Current definitions use Argv and Default; no process environment is read.
#derive(Debug, Eq)
pub(all) enum ValueSource {
  Argv
  Env
  Default
}

///|
pub extend ValueSource with Debug::{to_repr}

///|
pub extend ValueSource with Eq::{equal, not_equal}

///|
/// A parsed command without callback execution. The path excludes the application
/// name; an empty path selects the root. Context contains the selected command's
/// effective values, including ancestors, with the existing closest-value rules.
/// Its subcommand is None. Sources describe this parse snapshot; editing Context
/// afterwards does not change the recorded provenance.
pub struct Invocation {
  command_path : Array[String]
  context : Context
  priv sources : Map[String, ValueSource]
}

///|
/// The complete result of explicit argument parsing, without I/O or process exit.
/// Parsed does not require a callback; the host decides how to execute it.
pub(all) enum ParseOutcome {
  /// Effective values for the selected command, without running a callback.
  Parsed(Invocation)
  /// Display-ready help, including explicitly declared examples.
  Help(String)
  /// The application's version text, without an added trailing newline.
  Version(String)
  /// A parser or definition diagnostic. No error has been printed or raised.
  Failed(CliError)
}

///|
/// Returns the source of an effective value, or None when absent. A descendant
/// default shadows an ancestor argv value, just as it does in the callback API.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[
///     @cmder.int("count", default=Some(1)),
///   ])
///   guard app.parse(argv=[]) is Parsed(call) else { fail("expected arguments") }
///   assert_true(call.source_of("count") == Some(@cmder.ValueSource::Default))
/// }
/// ```
pub fn Invocation::source_of(self : Invocation, name : String) -> ValueSource? {
  self.sources.get(name)
}

///|
/// True only when the effective value came from argv, including explicit empty
/// strings. Defaults, environment values, and absent flags are not explicit.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[@cmder.string("name")])
///   guard app.parse(argv=["--name="]) is Parsed(call) else {
///     fail("expected arguments")
///   }
///   assert_true(call.was_provided("name"))
/// }
/// ```
pub fn Invocation::was_provided(self : Invocation, name : String) -> Bool {
  self.source_of(name) is Some(Argv)
}

///|
fn invocation_from_matches(matches : @argparse.Matches) -> Invocation {
  let command_path : Array[String] = []
  let sources : Map[String, ValueSource] = Map([])
  let mut current = matches
  let mut context : Context = { flags: {}, values: {}, subcommand: None, }
  while true {
    context = inherit_context(context, {
      flags: current.flags,
      values: current.values,
      subcommand: None,
    })
    for name, source in current.sources {
      sources[name] = match source {
        @argparse.ValueSource::Argv => Argv
        @argparse.ValueSource::Env => Env
        @argparse.ValueSource::Default => Default
      }
    }
    match current.subcommand {
      Some((name, child)) => {
        command_path.push(name)
        current = child
      }
      None => break
    }
  }
  { command_path, context, sources, }
}

///|
/// Parses explicit argv, excluding the executable name, without printing,
/// exiting, reading process state, or invoking callbacks. Integer conversion
/// remains lazy; use get_int_checked to distinguish invalid values from absence.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", version="1.2.3")
///   guard app.parse(argv=["--version"]) is Version(version) else {
///     fail("expected version")
///   }
///   inspect(version, content="1.2.3")
/// }
/// ```
pub fn CliApp::parse(self : CliApp, argv~ : ArrayView[String]) -> ParseOutcome {
  match build_cli_command(self).parse_outcome(argv~) {
    Parsed(matches) => Parsed(invocation_from_matches(matches))
    Help(text) => Help(text)
    Version(text) => Version(text)
    Failed(error) => Failed(CliError::ParseError(error.to_string()))
  }
}

///|
fn find_command_path(
  commands : Array[CommandDef],
  path : ArrayView[String],
) -> CommandDef? {
  guard path is [name, .. rest] else { return None }
  guard find_command_def(commands, name) is Some(command) else { return None }
  if rest.is_empty() {
    Some(command)
  } else {
    find_command_path(command.subcommands, rest)
  }
}

///|
/// Renders root or nested command help without parsing argv or running callbacks.
/// The path excludes the executable name. Unknown paths raise UnknownCommand;
/// descriptions, options, positionals, and explicit examples come from the same
/// command definition used by run and parse. Like argparse's render_help, this
/// renders definitions without validating whether they are executable.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", commands=[@cmder.command(name="go")])
///   assert_true(app.render_help(command_path=["go"]).contains("Usage: app go"))
/// }
/// ```
pub fn CliApp::render_help(
  self : CliApp,
  command_path~ : ArrayView[String] = [],
) -> String raise CliError {
  if command_path.is_empty() {
    return build_cli_command(self).render_help()
  }
  guard find_command_path(self.commands, command_path) is Some(command) else {
    raise CliError::UnknownCommand(command_path.to_owned())
  }
  build_command({
    ..command,
    name: "\{self.name} \{command_path.to_owned().join(" ")}",
  }).render_help()
}

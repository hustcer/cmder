///|
/// Errors produced by cmder. Parser diagnostics remain display-ready text;
/// cmder does not infer error categories by parsing argparse's messages.
#derive(Debug)
pub(all) suberror CliError {
  ParseError(String)
  InvalidDefinition(String)
  UnknownArgument(String)
  ArgumentTypeMismatch(name~ : String, expected~ : String)
  UnexpectedLocalArgument(command~ : String, name~ : String)
  InvalidOverride(String, String)
  MissingCommand
  UnknownCommand(Array[String])
  MissingSubcommand(String, Array[String])
  MissingHandler(String)
  MissingOption(String)
  MissingPositional(String)
  InvalidInteger(String, String)
  IntegerOutOfRange(String, String)
}

///|
pub extend CliError with Debug::{to_repr}

///|
pub extend CliError with Show::{output, to_string}

///|
/// Returns a display-ready message without source locations or a Failure prefix.
///
/// ```mbt check
/// test {
///   let error = @cmder.CliError::InvalidInteger("count", "abc")
///   inspect(error.message(), content="invalid integer for 'count': 'abc'")
/// }
/// ```
pub fn CliError::message(self : CliError) -> String {
  match self {
    ParseError(message) => message
    InvalidDefinition(message) => "invalid CLI definition: \{message}"
    UnknownArgument(name) => "unknown argument: \{name}"
    ArgumentTypeMismatch(name~, expected~) =>
      "argument '\{name}' cannot be read as \{expected}"
    UnexpectedLocalArgument(command~, name~) =>
      "local option '--\{name}' belongs to '\{command}' and cannot be used with a subcommand; declare it global=true to share it"
    InvalidOverride(name, reason) => "invalid override for '\{name}': \{reason}"
    MissingCommand => "no command specified. Use --help for usage."
    UnknownCommand(path) => "unknown command: \{path.join(" ")}"
    MissingSubcommand(command, available) =>
      "missing subcommand for '\{command}'. Available: \{available.join(", ")}"
    MissingHandler(command) => "no callback defined for command '\{command}'"
    MissingOption(name) => "missing required option: \{name}"
    MissingPositional(name) => "missing required positional argument: \{name}"
    InvalidInteger(name, value) => "invalid integer for '\{name}': '\{value}'"
    IntegerOutOfRange(name, value) =>
      "integer out of Int32 range for '\{name}': '\{value}'"
  }
}

///|
pub impl Show for CliError with fn output(self, logger) {
  logger.write_string(self.message())
}

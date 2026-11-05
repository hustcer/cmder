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

///|
#derive(Debug, Eq)
pub(all) enum OptionKind {
  StringOpt(String?)
  IntOpt(Int32?)
  BoolOpt
}

///|
pub extend OptionKind with Debug::{to_repr}

///|
pub extend OptionKind with Eq::{equal, not_equal}

///|
/// Immutable, normalized option metadata. Construct with string, int, or bool.
/// Defaults retain their declared type and make an option optional. Only global
/// options are visible to descendant commands.
#derive(Debug)
pub struct OptionDef {
  name : String
  kind : OptionKind
  short : Char?
  description : String
  required : Bool
  global : Bool
}

///|
pub extend OptionDef with Debug::{to_repr}

///|
/// Local positional metadata. multiple permits unbounded values only in the
/// final position; earlier positionals always accept at most one value.
pub struct PositionalDef {
  name : String
  description : String
  required : Bool
  multiple : Bool
}

///|
pub struct CommandDef {
  name : String
  description : String
  options : ReadOnlyArray[OptionDef]
  positionals : ReadOnlyArray[PositionalDef]
  examples : ReadOnlyArray[String]
  subcommands : ReadOnlyArray[CommandDef]
  run : ((Context) -> Unit raise)?
  required_scope_notice : String?
}

///|
pub struct Context {
  priv flags : Map[String, Bool]
  priv values : Map[String, Array[String]]
  priv sources : Map[String, ValueSource]
  priv specs : Map[String, ArgumentSpec]
}

///|
pub struct CliApp {
  root : CommandDef
  version : String
}

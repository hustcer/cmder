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
pub struct PositionalDef {
  name : String
  description : String
  required : Bool
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
}

///|
pub struct Context {
  priv flags : Map[String, Bool]
  priv values : Map[String, Array[String]]
  priv sources : Map[String, ValueSource]
}

///|
pub struct CliApp {
  root : CommandDef
  version : String
}

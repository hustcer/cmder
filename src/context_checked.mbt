///|
fn Context::check_read(
  self : Context,
  name : String,
  flag~ : Bool,
) -> Unit raise CliError {
  guard self.specs.get(name) is Some(spec) else {
    raise CliError::UnknownArgument(name)
  }
  let is_flag = spec is Option({ kind: BoolOpt, .. })
  if flag != is_flag {
    raise CliError::ArgumentTypeMismatch(
      name~,
      expected=if flag { "a Boolean flag" } else { "text" },
    )
  }
}

///|
fn Context::missing_value(self : Context, name : String) -> CliError {
  match self.specs.get(name) {
    Some(Positional(_, ..)) => CliError::MissingPositional(name)
    _ => CliError::MissingOption(name)
  }
}

///|
/// Reads a declared Boolean flag. Unknown names and value arguments raise CliError.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[@cmder.bool("loud")])
///   guard app.parse(argv=[]) is Parsed(call) else { fail("parse") }
///   assert_false(call.context.get_bool_checked("loud"))
/// }
/// ```
pub fn Context::get_bool_checked(
  self : Context,
  name : String,
) -> Bool raise CliError {
  self.check_read(name, flag=true)
  self.get_bool(name)
}

///|
/// Reads raw text from a declared string, integer or positional argument.
/// Unknown names and Boolean flags raise CliError; an absent declared value is None.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[@cmder.string("name")])
///   guard app.parse(argv=[]) is Parsed(call) else { fail("parse") }
///   assert_true(call.context.get_string_checked("name") is None)
/// }
/// ```
pub fn Context::get_string_checked(
  self : Context,
  name : String,
) -> String? raise CliError {
  self.check_read(name, flag=false)
  self.get_string(name)
}

///|
/// Returns a fresh copy of values after checking the declared name and kind.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", positionals=[@cmder.positional("files")])
///   guard app.parse(argv=["a", "b"]) is Parsed(call) else { fail("parse") }
///   assert_eq(call.context.get_strings_checked("files"), ["a", "b"])
/// }
/// ```
pub fn Context::get_strings_checked(
  self : Context,
  name : String,
) -> Array[String] raise CliError {
  self.check_read(name, flag=false)
  self.get_strings(name)
}

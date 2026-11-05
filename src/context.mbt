///|
/// Returns a flag's value, or false when it was not provided.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[@cmder.bool("verbose")])
///   guard app.parse(argv=["--verbose"]) is Parsed(call) else { fail("parse") }
///   assert_true(call.context.get_bool("verbose"))
/// }
/// ```
pub fn Context::get_bool(self : Context, name : String) -> Bool {
  self.flags.get(name).unwrap_or(false)
}

///|
/// Returns the first value, or `None` if the name is absent.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[
///     @cmder.string("name", default="Ada"),
///   ])
///   guard app.parse(argv=[]) is Parsed(call) else { fail("parse") }
///   assert_true(call.context.get_string("name") == Some("Ada"))
/// }
/// ```
pub fn Context::get_string(self : Context, name : String) -> String? {
  match self.values.get(name) {
    Some(arr) => if arr.length() > 0 { Some(arr[0]) } else { None }
    None => None
  }
}

///|
/// Returns the first value, raising CliError::MissingOption if it is absent.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[
///     @cmder.string("name", default="Ada"),
///   ])
///   guard app.parse(argv=[]) is Parsed(call) else { fail("parse") }
///   inspect(call.context.get_string_required("name"), content="Ada")
/// }
/// ```
pub fn Context::get_string_required(
  self : Context,
  name : String,
) -> String raise CliError {
  match self.get_string(name) {
    Some(v) => v
    None => raise CliError::MissingOption(name)
  }
}

///|
/// Reads a signed decimal Int32. Only absence returns None; malformed input
/// raises InvalidInteger and overflow raises IntegerOutOfRange. Leading zeroes
/// have no length limit. Declared integer options are already checked by parse.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[@cmder.int("count", default=3)])
///   guard app.parse(argv=[]) is Parsed(call) else { fail("parse") }
///   assert_true(call.context.get_int("count") == Some(3))
/// }
/// ```
pub fn Context::get_int(self : Context, name : String) -> Int32? raise CliError {
  guard self.get_string(name) is Some(value) else { return None }
  Some(parse_integer_value(name, value))
}

///|
/// Parses a required integer, raising MissingOption when absent and a checked
/// integer error when malformed or outside Int32. No application range is imposed.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[@cmder.int("count", default=3)])
///   guard app.parse(argv=[]) is Parsed(call) else { fail("parse") }
///   inspect(call.context.get_int_required("count"), content="3")
/// }
/// ```
pub fn Context::get_int_required(
  self : Context,
  name : String,
) -> Int32 raise CliError {
  match self.get_int(name) {
    Some(v) => v
    None => raise CliError::MissingOption(name)
  }
}

///|
// Shared by getters and parse-time validation.
fn parse_integer_value(name : String, value : String) -> Int32 raise CliError {
  let negative = value.has_prefix("-")
  let start = if negative { 1 } else { 0 }
  if start == value.length() {
    raise CliError::InvalidInteger(name, value)
  }
  // Validate the complete spelling before classifying overflow.
  for index in start..<value.length() {
    if value[index] < '0' || value[index] > '9' {
      raise CliError::InvalidInteger(name, value)
    }
  }
  let limit = if negative { 2147483648L } else { 2147483647L }
  let mut magnitude = 0L
  for index in start..<value.length() {
    let digit = (value[index].to_int() - 48).to_int64()
    if magnitude > (limit - digit) / 10L {
      raise CliError::IntegerOutOfRange(name, value)
    }
    magnitude = magnitude * 10L + digit
  }
  (if negative { -magnitude } else { magnitude }).to_int()
}

///|
/// Returns a fresh copy of all values associated with a name, or an empty array.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", positionals=[@cmder.positional("files")])
///   guard app.parse(argv=["a", "b"]) is Parsed(call) else { fail("parse") }
///   inspect(call.context.get_strings("files").length(), content="2")
/// }
/// ```
pub fn Context::get_strings(self : Context, name : String) -> Array[String] {
  self.values.get(name).map(values => values.copy()).unwrap_or([])
}

///|
/// Returns the current value's source, including explicit host overrides.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[@cmder.int("count", default=1)])
///   guard app.parse(argv=[]) is Parsed(call) else { fail("parse") }
///   assert_true(
///     call.context.source_of("count") == Some(@cmder.ValueSource::Default),
///   )
/// }
/// ```
pub fn Context::source_of(self : Context, name : String) -> ValueSource? {
  self.sources.get(name)
}

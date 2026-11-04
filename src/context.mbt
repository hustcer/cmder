///|
/// Returns a flag's value, or false when it was not provided.
///
/// ```mbt check
/// test {
///   let ctx : @cmder.Context = {
///     flags: { "verbose": true },
///     values: {},
///     subcommand: None,
///   }
///   assert_true(ctx.get_bool("verbose"))
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
///   let ctx : @cmder.Context = {
///     flags: {},
///     values: { "name": ["Ada"] },
///     subcommand: None,
///   }
///   assert_true(ctx.get_string("name") == Some("Ada"))
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
///   let ctx : @cmder.Context = {
///     flags: {},
///     values: { "name": ["Ada"] },
///     subcommand: None,
///   }
///   inspect(ctx.get_string_required("name"), content="Ada")
/// }
/// ```
pub fn Context::get_string_required(
  self : Context,
  name : String,
) -> String raise {
  match self.get_string(name) {
    Some(v) => v
    None => raise CliError::MissingOption(name)
  }
}

///|
/// Parses the first value as an `Int32`, returning `None` if missing or invalid.
///
/// ```mbt check
/// test {
///   let ctx : @cmder.Context = {
///     flags: {},
///     values: { "count": ["3"] },
///     subcommand: None,
///   }
///   assert_true(ctx.get_int("count") == Some(3))
/// }
/// ```
pub fn Context::get_int(self : Context, name : String) -> Int32? {
  guard self.get_string(name) is Some(value) else { return None }
  // Preserve the legacy length cap, even for arbitrarily padded zeroes.
  let digits = value.length() - (if value.has_prefix("-") { 1 } else { 0 })
  if digits > 18 {
    return None
  }
  self.get_int_checked(name) catch {
    _ => None
  }
}

///|
/// Parses a required integer, raising MissingOption when absent and a checked
/// integer error when malformed or outside Int32. No application range is imposed.
///
/// ```mbt check
/// test {
///   let ctx : @cmder.Context = {
///     flags: {},
///     values: { "count": ["3"] },
///     subcommand: None,
///   }
///   inspect(ctx.get_int_required("count"), content="3")
/// }
/// ```
pub fn Context::get_int_required(self : Context, name : String) -> Int32 raise {
  match self.get_int_checked(name) {
    Some(v) => v
    None => raise CliError::MissingOption(name)
  }
}

///|
/// Reads an optional signed decimal Int32. Missing values return None; empty,
/// nondecimal, and sign-only values raise InvalidInteger; overflow raises
/// IntegerOutOfRange. A leading minus is accepted, matching get_int's grammar.
/// Leading zeroes do not cause overflow. No product-specific range is checked.
///
/// ```mbt check
/// test {
///   let ctx : @cmder.Context = {
///     flags: {},
///     values: { "count": ["-2"] },
///     subcommand: None,
///   }
///   assert_true(ctx.get_int_checked("count") == Some(-2))
///   assert_true(ctx.get_int_checked("missing") is None)
/// }
/// ```
pub fn Context::get_int_checked(
  self : Context,
  name : String,
) -> Int32? raise CliError {
  guard self.get_string(name) is Some(value) else { return None }
  Some(parse_integer_value(name, value))
}

///|
// Shared by checked getters and opt-in parse-time type validation.
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
/// Returns all values associated with a name, or an empty array.
///
/// ```mbt check
/// test {
///   let ctx : @cmder.Context = {
///     flags: {},
///     values: { "files": ["a", "b"] },
///     subcommand: None,
///   }
///   inspect(ctx.get_strings("files").length(), content="2")
/// }
/// ```
pub fn Context::get_strings(self : Context, name : String) -> Array[String] {
  self.values.get(name).unwrap_or([])
}

///|
/// Returns the selected nested command and its context, if present.
///
/// ```mbt check
/// test {
///   let ctx : @cmder.Context = { flags: {}, values: {}, subcommand: None, }
///   assert_true(ctx.get_subcommand() is None)
/// }
/// ```
pub fn Context::get_subcommand(self : Context) -> (String, Context)? {
  self.subcommand
}

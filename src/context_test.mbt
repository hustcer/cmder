///|
fn context_value(name : String, value : String?) -> @cmder.Context raise {
  let app = @cmder.cli(name="app", options=[@cmder.string(name)])
  let argv = match value {
    Some(value) => ["--\{name}=\{value}"]
    None => []
  }
  expect_invocation(app.parse(argv~)).context
}

///|
test "get_bool returns a flag and false for absence" {
  let app = @cmder.cli(name="app", options=[@cmder.bool("verbose")])
  let ctx = expect_invocation(app.parse(argv=["--verbose"])).context
  assert_true(ctx.get_bool("verbose"))
  assert_false(ctx.get_bool("missing"))
}

///|
test "string getters distinguish empty values from absence" {
  let ctx = context_value("name", Some(""))
  assert_true(ctx.get_string("name") == Some(""))
  assert_eq(ctx.get_string_required("name"), "")
  assert_true(ctx.get_string("missing") is None)
  try ctx.get_string_required("missing") catch {
    @cmder.CliError::MissingOption("missing") => ()
    error => raise error
  } noraise {
    _ => fail("expected missing value")
  }
}

///|
test "integer getters distinguish absence format and range" {
  assert_true(context_value("count", None).get_int("count") is None)
  assert_true(context_value("count", Some("42")).get_int("count") == Some(42))
  assert_true(context_value("count", Some("-42")).get_int("count") == Some(-42))
  assert_eq(
    context_value("count", Some("8080")).get_int_required("count"),
    8080,
  )
  try context_value("count", None).get_int_required("count") catch {
    @cmder.CliError::MissingOption("count") => ()
    error => raise error
  } noraise {
    _ => fail("expected missing integer")
  }
  try context_value("count", Some("abc")).get_int("count") catch {
    @cmder.CliError::InvalidInteger("count", "abc") => ()
    error => raise error
  } noraise {
    _ => fail("expected malformed integer")
  }
  try
    context_value("count", Some("2147483648")).get_int_required("count")
  catch {
    @cmder.CliError::IntegerOutOfRange("count", "2147483648") => ()
    error => raise error
  } noraise {
    _ => fail("expected overflow")
  }
}

///|
test "get_strings returns an independent copy" {
  let app = @cmder.cli(name="app", positionals=[@cmder.positional("files")])
  let call = expect_invocation(app.parse(argv=["a.txt", "b.txt"]))
  let files = call.context.get_strings("files")
  files[0] = "edited"
  files.push("extra")
  assert_eq(call.context.get_strings("files"), ["a.txt", "b.txt"])
  assert_eq(call.context.get_strings("absent"), [])
  assert_true(call.context.source_of("files") == Some(@cmder.ValueSource::Argv))
}

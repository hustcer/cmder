///|
test "checked integers distinguish missing values from valid Int32 values" {
  let ctx : @cmder.Context = { flags: {}, values: {}, subcommand: None, }
  assert_true(ctx.get_int_checked("count") is None)
  for
    (text, expected) in [
      ("0", 0),
      ("-0", 0),
      ("42", 42),
      ("-42", -42),
      ("2147483647", 2147483647),
      ("-2147483648", -2147483648),
      ("0000000000000000000000000001", 1),
    ] {
    ctx.values["count"] = [text]
    assert_true(ctx.get_int_checked("count") == Some(expected))
  }
  assert_true(ctx.get_int("count") is None)
}

///|
test "checked integer errors identify format and preserve the input value" {
  for
    text in [
      "", "-", "+1", "1.5", " 1", "1 ", "1e2", "abc", "--quiet", "999999999999999999x",
    ] {
    let ctx : @cmder.Context = {
      flags: {},
      values: { "count": [text] },
      subcommand: None,
    }
    try ctx.get_int_checked("count") catch {
      @cmder.CliError::InvalidInteger(name, value) => {
        assert_eq(name, "count")
        assert_eq(value, text)
      }
      err => raise err
    } noraise {
      _ => fail("expected invalid integer")
    }
    assert_true(ctx.get_int("count") is None)
  }
}

///|
test "checked integers detect overflow before arithmetic can wrap" {
  for
    text in [
      "2147483648", "-2147483649", "9999999999999999999999999999999999999",
    ] {
    let ctx : @cmder.Context = {
      flags: {},
      values: { "count": [text] },
      subcommand: None,
    }
    try ctx.get_int_checked("count") catch {
      @cmder.CliError::IntegerOutOfRange(name, value) => {
        assert_eq(name, "count")
        assert_eq(value, text)
        assert_false(
          @cmder.CliError::IntegerOutOfRange(name, value)
          .message()
          .has_prefix("Failure("),
        )
      }
      err => raise err
    } noraise {
      _ => fail("expected overflow")
    }
    assert_true(ctx.get_int("count") is None)
  }
}

///|
test "required getters raise typed missing option errors" {
  let ctx : @cmder.Context = { flags: {}, values: {}, subcommand: None, }
  try ctx.get_string_required("name") catch {
    @cmder.CliError::MissingOption(name) => assert_eq(name, "name")
    err => raise err
  } noraise {
    _ => fail("expected missing string")
  }
  try ctx.get_int_required("count") catch {
    @cmder.CliError::MissingOption(name) => assert_eq(name, "count")
    err => raise err
  } noraise {
    _ => fail("expected missing integer")
  }
}

///|
test "checked integers work with parsed defaults and preserve legacy lazy parsing" {
  let app = @cmder.cli(name="app", options=[
    @cmder.int("count", default=Some(144)),
    @cmder.bool("quiet"),
  ])
  let defaults = expect_invocation(app.parse(argv=[]))
  assert_true(defaults.context.get_int_checked("count") == Some(144))
  assert_false(defaults.was_provided("count"))
  for argv in [["--count", "abc"], ["--count", "--quiet"]] {
    let call = expect_invocation(app.parse(argv~))
    assert_true(call.context.get_int("count") is None)
    assert_true(call.was_provided("count"))
    try call.context.get_int_checked("count") catch {
      @cmder.CliError::InvalidInteger(_, _) => ()
      err => raise err
    } noraise {
      _ => fail("expected invalid integer")
    }
  }
}

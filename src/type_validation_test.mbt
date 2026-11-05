///|
test "parse type validation is opt-in and distinguishes malformed values from overflow" {
  let app = @cmder.cli(name="app", options=[
    @cmder.int("count", short='c'),
    @cmder.bool("quiet"),
  ])
  for
    value in [
      "", "abc", "-", "+1", "1.5", " 1", "1 ", "1e2", "999999999999999999x", "--quiet",
    ] {
    let argv = ["--count", value]
    assert_true(app.parse(argv~) is Parsed(_))
    guard app.parse(argv~, validate_types=true)
      is Failed(@cmder.CliError::InvalidInteger(name, raw)) else {
      fail("expected invalid integer for '\{value}'")
    }
    assert_eq(name, "count")
    assert_eq(raw, value)
  }
  for value in ["2147483648", "-2147483649", "9999999999999999999999999999"] {
    assert_true(app.parse(argv=["-c", value]) is Parsed(_))
    guard app.parse(argv=["-c", value], validate_types=true)
      is Failed(@cmder.CliError::IntegerOutOfRange(name, raw)) else {
      fail("expected overflow for '\{value}'")
    }
    assert_eq(name, "count")
    assert_eq(raw, value)
  }
  assert_true(
    app.parse(argv=["--count=abc"], validate_types=true)
    is Failed(@cmder.CliError::InvalidInteger(_, _)),
  )
  assert_true(
    app.parse(argv=["-c2147483648"], validate_types=true)
    is Failed(@cmder.CliError::IntegerOutOfRange(_, _)),
  )
}

///|
test "validated parsing preserves raw values argv and sources without application ranges" {
  let app = @cmder.cli(name="app", options=[
    @cmder.int("count", default=Some(144)),
  ])
  let defaults = expect_invocation(app.parse(argv=[], validate_types=true))
  assert_true(defaults.context.get_int_checked("count") == Some(144))
  assert_false(defaults.was_provided("count"))
  for
    (raw, value) in [
      ("-1", -1),
      ("0", 0),
      ("-0", 0),
      ("2147483647", 2147483647),
      ("-2147483648", -2147483648),
      ("00000000000000000000000072", 72),
    ] {
    let argv = ["--count", raw]
    let call = expect_invocation(app.parse(argv~, validate_types=true))
    assert_true(call.context.get_string("count") == Some(raw))
    assert_true(call.context.get_int_checked("count") == Some(value))
    assert_true(call.was_provided("count"))
    assert_eq(argv, ["--count", raw])
  }
  // Validation does not change the legacy getter's documented length cap.
  let padded = expect_invocation(
    app.parse(
      argv=["--count", "00000000000000000000000072"],
      validate_types=true,
    ),
  )
  assert_true(padded.context.get_int("count") is None)
}

///|
test "type validation honors owning scopes before flattening inherited values" {
  let app = @cmder.cli(name="app", options=[@cmder.int("value")], commands=[
    @cmder.command(
      name="group",
      options=[@cmder.int("value", default=Some(3))],
      subcommands=[
        @cmder.command(name="go", positionals=[@cmder.positional("value")]),
      ],
    ),
  ])
  let call = expect_invocation(
    app.parse(argv=["--value", "2", "group", "go", "text"], validate_types=true),
  )
  assert_true(call.context.get_string("value") == Some("text"))
  assert_true(call.was_provided("value"))
  guard app.parse(
      argv=["--value", "bad", "group", "go", "text"],
      validate_types=true,
    )
    is Failed(@cmder.CliError::InvalidInteger("value", "bad")) else {
    fail("a descendant must not hide an invalid ancestor value")
  }
  assert_true(
    app.parse(
      argv=["group", "--value", "bad", "go", "text"],
      validate_types=true,
    )
    is Failed(@cmder.CliError::InvalidInteger(_, _)),
  )
  let child = @cmder.cli(name="app", options=[@cmder.string("value")], commands=[
    @cmder.command(name="go", options=[@cmder.int("value")]),
  ])
  // A missing child option does not reinterpret an ancestor's string value.
  let inherited = expect_invocation(
    child.parse(argv=["--value", "text", "go"], validate_types=true),
  )
  assert_true(inherited.context.get_string("value") == Some("text"))
  try inherited.context.get_int_checked("value") catch {
    @cmder.CliError::InvalidInteger("value", "text") => ()
    err => raise err
  } noraise {
    _ =>
      fail(
        "scope validation does not certify the inherited value as an integer",
      )
  }
  let explicit = expect_invocation(
    child.parse(
      argv=["--value", "text", "go", "--value", "2"],
      validate_types=true,
    ),
  )
  assert_true(explicit.context.get_int_checked("value") == Some(2))
  assert_true(
    child.parse(
      argv=["--value", "text", "go", "--value", "bad"],
      validate_types=true,
    )
    is Failed(@cmder.CliError::InvalidInteger(_, _)),
  )
}

///|
test "type validation checks selected defaults and skips unselected branches" {
  let invalid = { ..@cmder.int("count"), default_value: Some("bad"), }
  let app = @cmder.cli(name="app", commands=[
    @cmder.command(name="valid"),
    @cmder.command(name="invalid", options=[invalid], subcommands=[
      @cmder.command(name="child", options=[
        @cmder.int("count", default=Some(1)),
      ]),
    ]),
  ])
  assert_true(app.parse(argv=["valid"], validate_types=true) is Parsed(_))
  assert_true(app.parse(argv=["invalid"]) is Parsed(_))
  for argv in [["invalid"], ["invalid", "child"]] {
    assert_true(
      app.parse(argv~, validate_types=true)
      is Failed(@cmder.CliError::InvalidInteger("count", "bad")),
    )
  }
  let overridden = expect_invocation(
    app.parse(argv=["invalid", "--count", "2"], validate_types=true),
  )
  assert_true(overridden.context.get_int_checked("count") == Some(2))
  assert_true(overridden.was_provided("count"))
}

///|
test "type validation preserves help version structural errors and delimiters" {
  let app = @cmder.cli(
    name="app",
    version="1.2.3",
    options=[@cmder.int("count")],
    commands=[
      @cmder.command(name="go", positionals=[@cmder.positional("file")]),
    ],
  )
  assert_true(
    app.parse(argv=["--count", "bad", "--help"], validate_types=true) is Help(_),
  )
  assert_true(
    app.parse(argv=["--count", "bad", "--version"], validate_types=true)
    is Version("1.2.3"),
  )
  assert_true(
    app.parse(argv=["--unknown"], validate_types=true)
    is Failed(@cmder.CliError::ParseError(_)),
  )
  assert_true(
    app.parse(argv=["--count"], validate_types=true)
    is Failed(@cmder.CliError::ParseError(_)),
  )
  assert_true(
    app.parse(argv=["--count", "--help"], validate_types=true)
    is Failed(@cmder.CliError::InvalidInteger(_, _)),
  )
  let literal = expect_invocation(
    app.parse(argv=["go", "--", "--count=bad"], validate_types=true),
  )
  assert_true(literal.context.get_string("file") == Some("--count=bad"))
}

///|
test "run can validate types before dispatch while retaining its lazy default" {
  let calls = Ref(0)
  let app = @cmder.cli(name="app", commands=[
    @cmder.command(
      name="go",
      options=[@cmder.int("count")],
      run=Some(fn(_) { calls.val += 1 }),
    ),
  ])
  try app.run(argv=Some(["go", "--count", "bad"]), validate_types=true) catch {
    @cmder.CliError::InvalidInteger("count", "bad") => ()
    err => raise err
  } noraise {
    _ => fail("expected invalid integer")
  }
  assert_eq(calls.val, 0)
  app.run(argv=Some(["go", "--count", "bad"]))
  assert_eq(calls.val, 1)
  app.run(argv=Some(["go", "--count", "0"]), validate_types=true)
  assert_eq(calls.val, 2)
}

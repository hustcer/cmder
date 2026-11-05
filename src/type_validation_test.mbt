///|
test "parse always validates integer syntax and distinguishes overflow" {
  let app = @cmder.cli(name="app", options=[
    @cmder.int("count", short='c'),
    @cmder.bool("quiet"),
  ])
  for
    value in [
      "", "abc", "-", "+1", "1.5", " 1", "1 ", "1e2", "999999999999999999x", "--quiet",
    ] {
    guard app.parse(argv=["--count", value])
      is Failed(@cmder.CliError::InvalidInteger("count", raw)) else {
      fail("expected invalid integer")
    }
    assert_eq(raw, value)
  }
  for value in ["2147483648", "-2147483649", "9999999999999999999999999999"] {
    assert_true(
      app.parse(argv=["-c", value])
      is Failed(@cmder.CliError::IntegerOutOfRange(_, _)),
    )
  }
  assert_true(
    app.parse(argv=["--count=abc"])
    is Failed(@cmder.CliError::InvalidInteger(_, _)),
  )
  assert_true(
    app.parse(argv=["-c2147483648"])
    is Failed(@cmder.CliError::IntegerOutOfRange(_, _)),
  )
}

///|
test "parse preserves integer spelling argv and provenance without business constraints" {
  let app = @cmder.cli(name="app", options=[@cmder.int("count", default=144)])
  let defaults = expect_invocation(app.parse(argv=[]))
  assert_true(defaults.context.get_int("count") == Some(144))
  assert_true(defaults.source_of("count") == Some(@cmder.ValueSource::Default))
  for
    (raw, expected) in [
      ("-1", -1),
      ("0", 0),
      ("-0", 0),
      ("2147483647", 2147483647),
      ("-2147483648", -2147483648),
      ("00000000000000000000000072", 72),
    ] {
    let argv = ["--count", raw]
    let call = expect_invocation(app.parse(argv~))
    assert_true(call.context.get_string("count") == Some(raw))
    assert_true(call.context.get_int("count") == Some(expected))
    assert_true(call.was_provided("count"))
    assert_eq(argv, ["--count", raw])
  }
}

///|
test "ancestor locals do not leak into or get reinterpreted by child commands" {
  let app = @cmder.cli(name="app", options=[@cmder.string("value")], commands=[
    @cmder.command(name="go", options=[@cmder.int("value")]),
  ])
  let absent = expect_invocation(app.parse(argv=["--value", "text", "go"]))
  assert_true(absent.context.get_string("value") is None)
  assert_true(absent.context.get_int("value") is None)
  assert_true(absent.source_of("value") is None)
  let explicit = expect_invocation(
    app.parse(argv=["--value", "text", "go", "--value", "2"]),
  )
  assert_true(explicit.context.get_int("value") == Some(2))
  assert_true(
    app.parse(argv=["--value", "text", "go", "--value", "bad"])
    is Failed(@cmder.CliError::InvalidInteger("value", "bad")),
  )
}

///|
test "each selected scope validates its own inputs and unselected branches are skipped" {
  let app = @cmder.cli(name="app", options=[@cmder.int("value")], commands=[
    @cmder.command(name="go", options=[@cmder.string("value")]),
    @cmder.command(name="other", options=[@cmder.int("count", required=true)]),
  ])
  assert_true(app.parse(argv=["go"]) is Parsed(_))
  assert_true(
    app.parse(argv=["--value", "bad", "go", "--value", "text"])
    is Failed(@cmder.CliError::InvalidInteger("value", "bad")),
  )
}

///|
test "globals accept both argument placements and preserve explicit values over defaults" {
  let app = @cmder.cli(
    name="app",
    options=[@cmder.int("count", short='c', default=1, global=true)],
    commands=[
      @cmder.command(name="group", subcommands=[@cmder.command(name="go")]),
    ],
  )
  for
    argv in [
      ["--count", "2", "group", "go"],
      ["group", "--count", "2", "go"],
      ["group", "go", "--count", "2"],
    ] {
    let call = expect_invocation(app.parse(argv~))
    assert_true(call.context.get_int("count") == Some(2))
    assert_true(call.source_of("count") == Some(@cmder.ValueSource::Argv))
  }
  let call = expect_invocation(app.parse(argv=["group", "go"]))
  assert_true(call.context.get_int("count") == Some(1))
  assert_true(call.source_of("count") == Some(@cmder.ValueSource::Default))
}

///|
test "help version structural errors and delimiters retain precedence" {
  let app = @cmder.cli(
    name="app",
    version="1.2.3",
    options=[@cmder.int("count")],
    commands=[
      @cmder.command(name="go", positionals=[@cmder.positional("file")]),
    ],
  )
  assert_true(app.parse(argv=["--count", "bad", "--help"]) is Help(_))
  assert_true(
    app.parse(argv=["--count", "bad", "--version"]) is Version("1.2.3"),
  )
  assert_true(
    app.parse(argv=["--count", "bad", "--unknown"])
    is Failed(@cmder.CliError::ParseError(_)),
  )
  assert_true(
    app.parse(argv=["--count"]) is Failed(@cmder.CliError::ParseError(_)),
  )
  assert_true(
    app.parse(argv=["--count", "--help"])
    is Failed(@cmder.CliError::InvalidInteger(_, _)),
  )
  let literal = expect_invocation(app.parse(argv=["go", "--", "--count=bad"]))
  assert_true(literal.context.get_string("file") == Some("--count=bad"))
}

///|
test "required globals and flags work after deeply nested subcommands" {
  let app = @cmder.cli(
    name="app",
    options=[
      @cmder.int("count", required=true, global=true),
      @cmder.bool("verbose", short='v', global=true),
    ],
    commands=[
      @cmder.command(
        name="db",
        options=[@cmder.string("region", required=true, global=true)],
        subcommands=[@cmder.command(name="go")],
      ),
    ],
  )
  let call = expect_invocation(
    app.parse(argv=["db", "go", "--count", "-2", "--region", "west", "-v"]),
  )
  assert_true(call.context.get_int("count") == Some(-2))
  assert_true(call.context.get_bool("verbose"))
  assert_true(call.context.get_string("region") == Some("west"))
  assert_true(call.was_provided("count"))
  assert_true(call.was_provided("region"))
  assert_true(call.was_provided("verbose"))
  assert_true(
    app.parse(argv=["db", "go"]) is Failed(@cmder.CliError::ParseError(_)),
  )
}

///|
test "nested help exposes globals while excluding ancestor locals" {
  let app = @cmder.cli(
    name="app",
    options=[
      @cmder.int("count", default=1, global=true),
      @cmder.string("root-local"),
    ],
    commands=[@cmder.command(name="go", options=[@cmder.bool("quiet")])],
  )
  guard app.parse(argv=["go", "--help"]) is Help(parsed) else { fail("help") }
  let rendered = app.render_help(command_path=["go"])
  for text in [parsed, rendered] {
    assert_true(text.contains("--count"))
    assert_true(text.contains("--quiet"))
    assert_false(text.contains("--root-local"))
  }
  assert_true(
    app.parse(argv=["go", "--root-local", "x"])
    is Failed(@cmder.CliError::ParseError(_)),
  )
}

///|
test "global spellings shadow builtins consistently" {
  let app = @cmder.cli(
    name="app",
    options=[@cmder.string("help", global=true)],
    commands=[@cmder.command(name="go")],
  )
  assert_true(app.parse(argv=["go", "-h"]) is Help(_))
  let call = expect_invocation(app.parse(argv=["go", "--help", "manual"]))
  assert_true(call.context.get_string("help") == Some("manual"))
}

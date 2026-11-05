///|
test "parent command lists contain descriptions without child examples or notices" {
  let app = @cmder.cli(name="app", commands=[
    @cmder.command(
      name="group",
      description="Group commands",
      options=[@cmder.string("token", required=true)],
      examples=["app group --token x"],
      subcommands=[@cmder.command(name="leaf")],
    ),
    @cmder.command(name="next", description="Next command"),
  ])
  for
    text in [
      app.render_help(),
      match app.parse(argv=["--bad"]) {
        Failed(error) => error.message()
        _ => fail("error")
      },
    ] {
    assert_true(text.contains("group  Group commands\n  next"))
    assert_false(text.contains("Examples:"))
    assert_false(text.contains("Local required options"))
  }
  let own = app.render_help(command_path=["group"])
  assert_true(own.contains("Examples:\n  app group --token x"))
  assert_true(own.contains("Local required options (--token)"))
}

///|
test "explicit and error help retain required globals locals and positionals" {
  let app = @cmder.cli(
    name="app",
    options=[@cmder.string("auth", required=true, global=true)],
    commands=[
      @cmder.command(
        name="go",
        options=[@cmder.bool("verbose"), @cmder.string("name", required=true)],
        positionals=[@cmder.positional("file", required=true, multiple=false)],
        examples=["app go --auth x --name n file"],
      ),
    ],
  )
  let help = app.render_help(command_path=["go"])
  assert_true(help.has_prefix("Usage: app go --auth <auth> --name <name>"))
  assert_true(help.contains("<file>"))
  for argv in [["go", "--bad"], ["go", "--name"], ["go", "a", "b"]] {
    guard app.parse(argv~) is Failed(@cmder.CliError::ParseError(text)) else {
      fail("structural error")
    }
    assert_true(text.has_suffix(help))
    assert_true(text.has_prefix("error:"))
  }
  for argv in [["go", "--help"], ["help", "go"]] {
    guard app.parse(argv~) is Help(text) else { fail("help") }
    assert_eq(text + "\n", help)
  }
  assert_true(
    app.parse(argv=["go"]) is Failed(@cmder.CliError::MissingOption("auth")),
  )
  assert_true(
    app.parse(argv=["go", "--auth", "x"])
    is Failed(@cmder.CliError::MissingOption("name")),
  )
  assert_true(
    app.parse(argv=["go", "--auth", "x", "--name", "n"])
    is Failed(@cmder.CliError::MissingPositional("file")),
  )
}

///|
test "scope notices can be localized or disabled without affecting parent lists" {
  for notice in ["局部必填参数只用于本命令。", ""] {
    let app = @cmder.cli(
      name="app",
      options=[@cmder.string("token", required=true)],
      required_scope_notice=notice,
      commands=[@cmder.command(name="go")],
    )
    let help = app.render_help()
    assert_false(help.contains("Local required options"))
    if !notice.is_empty() {
      assert_true(help.contains(notice))
    }
    guard app.parse(argv=["--help"]) is Help(parsed) else { fail("help") }
    assert_eq(parsed + "\n", help)
  }
}

///|
test "single final positionals reject extra input and atomic overrides" {
  let app = @cmder.cli(name="rm1", positionals=[
    @cmder.positional("file", required=true, multiple=false),
  ])
  assert_true(
    app.parse(argv=["a", "b"]) is Failed(@cmder.CliError::ParseError(_)),
  )
  let call = expect_invocation(app.parse(argv=["a"]))
  try
    call.with_overrides({
      "file": @cmder.ArgumentValue::Positionals(["b", "c"]),
    })
  catch {
    @cmder.CliError::InvalidOverride("file", _) => ()
    error => raise error
  } noraise {
    _ => fail("cardinality")
  }
  assert_eq(call.context.get_strings("file"), ["a"])
  assert_true(
    app.render_schema_json()
    is { "positionals": { "file": { "max_args": 1, .. }, .. }, .. },
  )
}

///|
test "strict reads distinguish unknown names absent values and incompatible kinds" {
  let app = @cmder.cli(name="app", options=[
    @cmder.string("name"),
    @cmder.string("number", default="7"),
    @cmder.int("count", default=3),
    @cmder.bool("loud"),
  ])
  let call = expect_invocation(app.parse(argv=[]))
  let ctx = call.context
  assert_true(ctx.get_string_checked("name") is None)
  assert_true(ctx.get_int("name") is None)
  assert_false(ctx.get_bool_checked("loud"))
  assert_true(ctx.get_int("number") == Some(7))
  assert_true(ctx.get_string_checked("count") == Some("3"))
  for
    read in [
      () => ignore(ctx.get_string_checked("nmae")),
      () => ignore(ctx.get_int("nope")),
      () => ignore(ctx.get_bool_checked("loudd")),
      () => ignore(ctx.get_string_required("nmae")),
      () => ignore(ctx.get_strings_checked("files")),
    ] {
    try read() catch {
      @cmder.CliError::UnknownArgument(_) => ()
      error => raise error
    } noraise {
      _ => fail("unknown name")
    }
  }
  for
    read in [
      () => ignore(ctx.get_bool_checked("name")),
      () => ignore(ctx.get_string_checked("loud")),
      () => ignore(ctx.get_int("loud")),
    ] {
    try read() catch {
      @cmder.CliError::ArgumentTypeMismatch(..) => ()
      error => raise error
    } noraise {
      _ => fail("wrong kind")
    }
  }
  let edited = call.with_overrides({ "name": @cmder.ArgumentValue::Text("Ada") })
  assert_true(edited.context.get_string_checked("name") == Some("Ada"))
}

///|
test "empty leaf schema examples retain all required ancestor globals" {
  let app = @cmder.cli(
    name="app",
    options=[
      @cmder.string("auth", required=true, global=true),
      @cmder.string("token", required=true),
    ],
    commands=[@cmder.command(name="go")],
  )
  assert_true(
    app.render_schema_json()
    is {
      "commands": { "go": { "examples": ["app --auth <auth> go"], .. }, .. },
      ..
    },
  )
}

///|
test "integer values do not consume flags and normalization respects scope and tokens" {
  let app = @cmder.cli(
    name="app",
    options=[@cmder.int("count", short='c'), @cmder.bool("verbose", short='v')],
    commands=[
      @cmder.command(name="go", options=[@cmder.string("count", short='c')]),
    ],
  )
  for argv in [["--count", "--help"], ["-vc", "-h"], ["--count", "-vh"]] {
    assert_true(app.parse(argv~) is Help(_))
  }
  for argv in [["--count", "--verbose"], ["-c", "-v"], ["--count", "--"]] {
    assert_true(app.parse(argv~) is Failed(@cmder.CliError::ParseError(_)))
  }
  for
    argv in [
      ["--count", "1", "--count", "--help"],
      ["-c1", "-vc", "-h"],
      ["--count", "-xh"],
    ] {
    assert_true(app.parse(argv~) is Failed(@cmder.CliError::ParseError(_)))
  }
  for argv in [["--count", "-2"], ["-vc", "-2"]] {
    let call = expect_invocation(app.parse(argv~))
    assert_true(call.context.get_int("count") == Some(-2))
    assert_true(call.context.get_string("count") == Some("-2"))
  }
  assert_true(
    app.parse(argv=["go", "--count", "-2"])
    is Failed(@cmder.CliError::ParseError(_)),
  )
  let call = expect_invocation(app.parse(argv=["go", "--count=-2"]))
  assert_true(call.context.get_string("count") == Some("-2"))
  let shadowed = @cmder.cli(name="app", options=[
    @cmder.int("count"),
    @cmder.string("help", short='h'),
  ])
  assert_true(
    shadowed.parse(argv=["--count", "--help"])
    is Failed(@cmder.CliError::ParseError(_)),
  )
  let clustered_shadow = @cmder.cli(name="app", options=[
    @cmder.int("count"),
    @cmder.bool("verbose", short='v'),
    @cmder.bool("custom-help", short='h'),
  ])
  assert_true(
    clustered_shadow.parse(argv=["--count", "-vh"])
    is Failed(@cmder.CliError::ParseError(_)),
  )
}

///|
test "help preserves mixed argument ordering through multiple ancestor scopes" {
  let app = @cmder.cli(
    name="app",
    options=[
      @cmder.string("auth", required=true, global=true),
      @cmder.bool("trace", global=true),
    ],
    commands=[
      @cmder.command(
        name="group",
        options=[
          @cmder.bool("dry"),
          @cmder.string("region", required=true, global=true),
          @cmder.string("token", required=true),
        ],
        examples=["app group --auth x --region y --token z"],
        subcommands=[
          @cmder.command(
            name="leaf",
            options=[
              @cmder.bool("verbose"),
              @cmder.string("name", required=true),
            ],
            examples=["app group leaf --auth x --region y --name n"],
          ),
        ],
      ),
    ],
  )
  for path in [["group"], ["group", "leaf"]] {
    let expected = app.render_help(command_path=path)
    for argv in [path + ["--help"], ["help"] + path] {
      guard app.parse(argv~) is Help(text) else { fail("help") }
      assert_eq(text + "\n", expected)
      assert_true(text.contains("--auth <auth> --region <region>"))
      assert_true(text.contains("Examples:"))
    }
    guard app.parse(argv=path + ["--bad"])
      is Failed(@cmder.CliError::ParseError(text)) else {
      fail("error")
    }
    assert_true(text.has_suffix(expected))
  }
}

///|
test "required getters report positional absence separately from unknown names" {
  let call = expect_invocation(
    @cmder.cli(name="app", positionals=[
      @cmder.positional("file", multiple=false),
    ]).parse(argv=[]),
  )
  for
    read in [
      () => ignore(call.context.get_string_required("file")),
      () => ignore(call.context.get_int_required("file")),
    ] {
    try read() catch {
      @cmder.CliError::MissingPositional("file") => ()
      error => raise error
    } noraise {
      _ => fail("absent positional")
    }
  }
}

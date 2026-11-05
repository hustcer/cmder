///|
fn expect_invocation(outcome : @cmder.ParseOutcome) -> @cmder.Invocation raise {
  match outcome {
    Parsed(invocation) => invocation
    Failed(error) => fail(error.message())
    _ => fail("expected a parsed invocation")
  }
}

///|
test "parse selects a command without executing any callbacks" {
  let called = Ref(false)
  let app = @cmder.cli(
    name="app",
    options=[@cmder.bool("verbose", global=true)],
    commands=[
      @cmder.command(name="group", run=_ => called.val = true, subcommands=[
        @cmder.command(name="go", positionals=[@cmder.positional("files")], run=_ => {
          called.val = true
        }),
      ]),
    ],
  )
  let argv = ["--verbose", "group", "go", "a.txt", "b.txt"]
  let invocation = expect_invocation(app.parse(argv~))
  assert_false(called.val)
  assert_true(invocation.command_path == ["group", "go"])
  assert_true(invocation.context.get_bool("verbose"))
  @debug.debug_inspect(
    invocation.context.get_strings("files"),
    content="[\"a.txt\", \"b.txt\"]",
  )
  assert_true(invocation.was_provided("files"))
  @debug.debug_inspect(
    argv,
    content="[\"--verbose\", \"group\", \"go\", \"a.txt\", \"b.txt\"]",
  )
}

///|
test "parse accepts root arguments and commands without callbacks" {
  let app = @cmder.cli(
    name="app",
    options=[@cmder.int("count", default=2, global=true)],
    commands=[
      @cmder.command(name="group", subcommands=[@cmder.command(name="leaf")]),
    ],
  )
  let root = expect_invocation(app.parse(argv=[]))
  assert_true(root.command_path.is_empty())
  assert_true(root.context.get_int("count") == Some(2))
  assert_true(root.source_of("count") == Some(@cmder.ValueSource::Default))
  assert_false(root.was_provided("count"))
  let leaf = expect_invocation(app.parse(argv=["group", "leaf"]))
  assert_eq(leaf.command_path.length(), 2)
  assert_true(leaf.context.get_int("count") == Some(2))
}

///|
test "parse returns help version and failures without terminating the host" {
  let called = Ref(false)
  let app = @cmder.cli(name="app", version="1.2.3", commands=[
    @cmder.command(name="go", examples=["app go"], run=_ => called.val = true),
  ])
  for argv in [["go", "--help"], ["help", "go"]] {
    guard app.parse(argv~) is Help(text) else { fail("expected help") }
    assert_true(text.contains("Usage: app go"))
    assert_true(text.contains("Examples:\n  app go"))
  }
  for argv in [["--version"], ["-V"]] {
    guard app.parse(argv~) is Version(text) else { fail("expected version") }
    assert_eq(text, "1.2.3")
  }
  guard app.parse(argv=["go", "--unknown"]) is Failed(error) else {
    fail("expected a parser error")
  }
  guard error is @cmder.CliError::ParseError(message) else {
    fail("expected parser diagnostic")
  }
  assert_true(message.contains("--unknown"))
  assert_true(message.contains("Usage: app go"))
  assert_eq(error.to_string(), message)
  assert_false(called.val)
}

///|
test "source queries preserve explicit default-equivalent and empty values" {
  let app = @cmder.cli(name="app", options=[
    @cmder.string("name", default=""),
    @cmder.int("count", default=2),
    @cmder.bool("verbose"),
  ])
  let defaults = expect_invocation(app.parse(argv=[]))
  assert_false(defaults.was_provided("name"))
  assert_true(defaults.source_of("name") == Some(@cmder.ValueSource::Default))
  assert_true(defaults.source_of("verbose") is None)
  let explicit = expect_invocation(
    app.parse(argv=["--name=", "--count=2", "--verbose"]),
  )
  assert_true(explicit.was_provided("name"))
  assert_true(explicit.was_provided("count"))
  assert_true(explicit.was_provided("verbose"))
  assert_true(explicit.source_of("name") == Some(@cmder.ValueSource::Argv))
  assert_true(explicit.source_of("missing") is None)
  assert_false(explicit.was_provided("missing"))
}

///|
test "effective sources belong to visible locals and globals" {
  let app = @cmder.cli(
    name="app",
    options=[
      @cmder.string("mode"),
      @cmder.string("region", global=true),
      @cmder.string("verbose"),
    ],
    commands=[
      @cmder.command(name="go", options=[
        @cmder.string("mode", default="child"),
        @cmder.bool("verbose"),
      ]),
    ],
  )
  let call = expect_invocation(
    app.parse(argv=["--region", "west", "go", "--verbose"]),
  )
  assert_true(call.context.get_string("mode") == Some("child"))
  assert_true(call.source_of("mode") == Some(@cmder.ValueSource::Default))
  assert_false(call.was_provided("mode"))
  assert_true(call.context.get_string("region") == Some("west"))
  assert_true(call.was_provided("region"))
  assert_true(call.context.get_string("verbose") is None)
  assert_true(call.context.get_bool("verbose"))
  assert_true(call.was_provided("verbose"))
}

///|
test "parse invocations do not share mutable values or source snapshots" {
  let app = @cmder.cli(name="app", options=[
    @cmder.string("name", default="original"),
  ])
  let first = expect_invocation(app.parse(argv=[]))
  let edited = first.with_overrides({
    "name": @cmder.ArgumentValue::Text("changed"),
  })
  assert_true(edited.context.get_string("name") == Some("changed"))
  assert_true(first.source_of("name") == Some(@cmder.ValueSource::Default))
  assert_true(first.source_of("other") is None)
  let second = expect_invocation(app.parse(argv=[]))
  assert_true(second.context.get_string("name") == Some("original"))
  assert_false(second.context.get_bool("other"))
  assert_true(second.source_of("name") == Some(@cmder.ValueSource::Default))
}

///|
test "invalid definitions fail during construction before parsing" {
  expect_definition_error(() => {
    @cmder.cli(name="app", options=[@cmder.string("name"), @cmder.bool("name")])
  })
}

///|
test "render_help works for nested paths and shadowed builtin flags" {
  let app = @cmder.cli(name="app", options=[@cmder.string("help", short='h')], commands=[
    @cmder.command(name="group", subcommands=[
      @cmder.command(name="go", examples=["app group go"]),
    ]),
  ])
  assert_true(app.render_help().contains("--help <help>"))
  let text = app.render_help(command_path=["group", "go"])
  assert_true(text.contains("Usage: app group go"))
  assert_true(text.contains("Examples:\n  app group go"))
  try app.render_help(command_path=["missing"]) catch {
    @cmder.CliError::UnknownCommand(path) => assert_eq(path[0], "missing")
    err => raise err
  } noraise {
    _ => fail("expected unknown command")
  }
}

///|
test "run raises typed missing command subcommand and callback errors" {
  let app = @cmder.cli(name="app", commands=[
    @cmder.command(name="group", subcommands=[@cmder.command(name="leaf")]),
  ])
  try app.run(argv=[]) catch {
    @cmder.CliError::MissingCommand => ()
    err => raise err
  } noraise {
    _ => fail("expected missing command")
  }
  try app.run(argv=["group"]) catch {
    @cmder.CliError::MissingSubcommand(name, available) => {
      assert_eq(name, "group")
      assert_eq(available[0], "leaf")
    }
    err => raise err
  } noraise {
    _ => fail("expected missing subcommand")
  }
  try app.run(argv=["group", "leaf"]) catch {
    @cmder.CliError::MissingHandler(name) => assert_eq(name, "leaf")
    err => raise err
  } noraise {
    _ => fail("expected missing callback")
  }
}

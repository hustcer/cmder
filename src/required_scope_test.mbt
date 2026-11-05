///|
test "local required options constrain only the selected command" {
  let seen = Ref("")
  let app = @cmder.cli(
    name="app",
    options=[@cmder.string("token", required=true)],
    run=ctx => seen.val = ctx.get_string_required("token"),
    commands=[
      @cmder.command(name="go", run=ctx => {
        assert_true(ctx.get_string("token") is None)
        seen.val = "child"
      }),
    ],
  )
  assert_true(
    app.parse(argv=[]) is Failed(@cmder.CliError::MissingOption("token")),
  )
  app.run(argv=["--token", "root"])
  assert_eq(seen.val, "root")
  app.run(argv=["go"])
  assert_eq(seen.val, "child")
  app.run(argv=["--token", "unused", "go"])
  assert_eq(seen.val, "child")
  assert_true(app.parse(argv=["go", "--token", "x"]) is Failed(_))
}

///|
test "nested locals and repeated names have independent required checks" {
  let app = @cmder.cli(
    name="app",
    options=[@cmder.string("token", required=true)],
    commands=[
      @cmder.command(
        name="group",
        options=[@cmder.int("token", required=true)],
        subcommands=[
          @cmder.command(name="leaf", options=[
            @cmder.string("token", required=true),
          ]),
        ],
      ),
    ],
  )
  assert_true(
    app.parse(argv=["group"]) is Failed(@cmder.CliError::MissingOption("token")),
  )
  let group = expect_invocation(app.parse(argv=["group", "--token", "2"]))
  assert_true(group.context.get_int("token") == Some(2))
  assert_true(
    app.parse(argv=["--token", "root", "group", "--token", "2", "leaf"])
    is Failed(@cmder.CliError::MissingOption("token")),
  )
  let leaf = expect_invocation(
    app.parse(argv=["group", "leaf", "--token", "child"]),
  )
  assert_true(leaf.context.get_string("token") == Some("child"))
}

///|
test "explicit ancestor integer inputs remain checked" {
  let app = @cmder.cli(
    name="app",
    options=[@cmder.int("count", required=true)],
    commands=[@cmder.command(name="go")],
  )
  ignore(expect_invocation(app.parse(argv=["go"])))
  assert_true(
    app.parse(argv=["--count", "bad", "go"])
    is Failed(@cmder.CliError::InvalidInteger("count", "bad")),
  )
  assert_true(
    app.parse(argv=["--count", "2147483648", "go"])
    is Failed(@cmder.CliError::IntegerOutOfRange("count", "2147483648")),
  )
  assert_true(
    app.parse(argv=["--count", "bad", "--unknown", "go"])
    is Failed(@cmder.CliError::ParseError(_)),
  )
}

///|
test "global required values constrain every descendant and remain readable" {
  let app = @cmder.cli(
    name="app",
    options=[@cmder.string("token", required=true, global=true)],
    commands=[
      @cmder.command(name="group", subcommands=[@cmder.command(name="leaf")]),
    ],
  )
  for argv in [[], ["group"], ["group", "leaf"]] {
    assert_true(app.parse(argv~) is Failed(@cmder.CliError::ParseError(_)))
  }
  for
    argv in [
      ["--token", "x", "group", "leaf"],
      ["group", "--token", "x", "leaf"],
      ["group", "leaf", "--token", "x"],
    ] {
    let call = expect_invocation(app.parse(argv~))
    assert_true(call.context.get_string("token") == Some("x"))
    assert_true(call.was_provided("token"))
  }
}

///|
test "help and version precede selected local required checks" {
  let app = @cmder.cli(
    name="app",
    version="1.0",
    options=[@cmder.string("token", required=true)],
    commands=[
      @cmder.command(name="go", options=[@cmder.int("count", required=true)]),
    ],
  )
  for
    (argv, path) in [
      (["--help"], []),
      (["go", "--help"], ["go"]),
      (["help", "go"], ["go"]),
    ] {
    guard app.parse(argv~) is Help(text) else { fail("expected help") }
    assert_eq(text + "\n", app.render_help(command_path=path))
    assert_true(
      text.has_prefix(
        if path.is_empty() {
          "Usage: app --token <token>"
        } else {
          "Usage: app go --count <count>"
        },
      ),
    )
  }
  assert_true(app.parse(argv=["--version"]) is Version("1.0"))
  assert_true(
    app.parse(argv=["--token", "x", "go", "--count", "bad", "--help"])
    is Help(_),
  )
}

///|
test "group help explains local required scope while interop keeps raw semantics" {
  let app = @cmder.cli(
    name="app",
    options=[
      @cmder.string("token", required=true),
      @cmder.string("auth", required=true, global=true),
    ],
    commands=[
      @cmder.command(
        name="group",
        options=[@cmder.int("count", required=true)],
        subcommands=[@cmder.command(name="leaf")],
      ),
    ],
  )
  let root = app.render_help()
  assert_true(
    root.contains(
      "Local required options (--token) apply only to this command's own execution.",
    ),
  )
  let group = app.render_help(command_path=["group"])
  assert_true(
    group.contains(
      "Local required options (--count) apply only to this command's own execution.",
    ),
  )
  assert_true(group.contains("--auth <auth>"))
  assert_false(group.contains("--token"))
  assert_false(
    app
    .render_help(command_path=["group", "leaf"])
    .contains("Local required options"),
  )
  for argv in [["group", "--help"], ["help", "group"]] {
    guard app.parse(argv~) is Help(text) else { fail("expected help") }
    assert_eq(text + "\n", group)
  }
  let raw = @cmder.build_command(app.root)
  assert_false(raw.render_help().contains("Local required options"))
  assert_true(
    raw.parse_outcome(argv=["--auth", "x", "group", "--count", "2", "leaf"])
    is Failed(_),
  )
  ignore(expect_invocation(app.parse(argv=["--auth", "x", "group", "leaf"])))
}

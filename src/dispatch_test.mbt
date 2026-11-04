///|
test "dispatch runs only the selected callback with its parsed inherited context" {
  let calls = Ref(0)
  let seen = Ref("")
  let app = @cmder.cli(name="app", options=[@cmder.string("mode")], commands=[
    @cmder.command(name="group", run=Some(fn(_) { calls.val += 100 }), subcommands=[
      @cmder.command(
        name="go",
        options=[@cmder.string("mode", default=Some("child"))],
        run=Some(fn(ctx) {
          calls.val += 1
          seen.val = ctx.get_string("mode").unwrap_or("")
        }),
      ),
    ]),
  ])
  let argv = ["--mode", "parent", "group", "go"]
  let call = expect_invocation(app.parse(argv~))
  assert_eq(calls.val, 0)
  argv[1] = "changed argv"
  app.dispatch(call)
  assert_eq(calls.val, 1)
  assert_eq(seen.val, "child")
  call.context.values["mode"] = ["edited context"]
  app.dispatch(call)
  assert_eq(calls.val, 2)
  assert_eq(seen.val, "edited context")
  assert_true(call.source_of("mode") == Some(@cmder.ValueSource::Default))
}

///|
test "dispatch returns typed command errors without invoking callbacks" {
  let called = Ref(false)
  let app = @cmder.cli(name="app", commands=[
    @cmder.command(name="group", subcommands=[@cmder.command(name="leaf")]),
    @cmder.command(name="go", run=Some(fn(_) { called.val = true })),
  ])
  try app.dispatch(expect_invocation(app.parse(argv=[]))) catch {
    @cmder.CliError::MissingCommand => ()
    err => raise err
  } noraise {
    _ => fail("expected missing command")
  }
  try app.dispatch(expect_invocation(app.parse(argv=["group"]))) catch {
    @cmder.CliError::MissingSubcommand(name, available) => {
      assert_eq(name, "group")
      assert_eq(available, ["leaf"])
    }
    err => raise err
  } noraise {
    _ => fail("expected missing subcommand")
  }
  try app.dispatch(expect_invocation(app.parse(argv=["group", "leaf"]))) catch {
    @cmder.CliError::MissingHandler(name) => assert_eq(name, "leaf")
    err => raise err
  } noraise {
    _ => fail("expected missing handler")
  }
  let call = expect_invocation(app.parse(argv=["group", "leaf"]))
  call.command_path[1] = "unknown"
  try app.dispatch(call) catch {
    @cmder.CliError::UnknownCommand(path) =>
      assert_eq(path, ["group", "unknown"])
    err => raise err
  } noraise {
    _ => fail("expected unknown path")
  }
  assert_false(called.val)
}

///|
test "dispatch uses current definitions without reparsing or replacing defaults" {
  let seen = Ref("")
  let original = @cmder.cli(name="original", commands=[
    @cmder.command(name="go", options=[
      @cmder.string("value", default=Some("original")),
    ]),
  ])
  let current = @cmder.cli(name="current", commands=[
    @cmder.command(
      name="go",
      options=[@cmder.string("value", default=Some("current"))],
      run=Some(fn(ctx) { seen.val = ctx.get_string("value").unwrap_or("") }),
    ),
  ])
  current.dispatch(expect_invocation(original.parse(argv=["go"])))
  assert_eq(seen.val, "original")
}

///|
test "dispatch does not silently enable type validation" {
  let seen = Ref("")
  let app = @cmder.cli(name="app", commands=[
    @cmder.command(
      name="go",
      options=[@cmder.int("count")],
      run=Some(fn(ctx) { seen.val = ctx.get_string("count").unwrap_or("") }),
    ),
  ])
  app.dispatch(expect_invocation(app.parse(argv=["go", "--count", "bad"])))
  assert_eq(seen.val, "bad")
}

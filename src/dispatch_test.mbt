///|
suberror TestBusinessError {
  Denied(String)
}

///|
test "bound dispatch selects one callback and propagates original business errors" {
  let calls = Ref(0)
  let commands = [
    @cmder.command(name="group", run=_ => calls.val += 100, subcommands=[
      @cmder.command(name="go", run=_ => {
        calls.val += 1
        raise TestBusinessError::Denied("database")
      }),
    ]),
  ]
  let app = @cmder.cli(name="app", commands~)
  let call = expect_invocation(app.parse(argv=["group", "go"]))
  commands[0] = @cmder.command(name="replacement")
  assert_eq(calls.val, 0)
  for _ in 0..<2 {
    try call.dispatch() catch {
      TestBusinessError::Denied("database") => ()
      error => raise error
    } noraise {
      _ => fail("expected original business error")
    }
  }
  assert_eq(calls.val, 2)
  try app.run(argv=["group", "go"]) catch {
    TestBusinessError::Denied("database") => ()
    error => raise error
  } noraise {
    _ => fail("expected original error through run")
  }
  assert_eq(calls.val, 3)
}

///|
test "bound dispatch returns typed missing root group and leaf errors" {
  let app = @cmder.cli(name="app", commands=[
    @cmder.command(name="group", subcommands=[@cmder.command(name="leaf")]),
  ])
  try expect_invocation(app.parse(argv=[])).dispatch() catch {
    @cmder.CliError::MissingCommand => ()
    error => raise error
  } noraise {
    _ => fail("expected missing command")
  }
  try expect_invocation(app.parse(argv=["group"])).dispatch() catch {
    @cmder.CliError::MissingSubcommand("group", available) =>
      assert_eq(available, ["leaf"])
    error => raise error
  } noraise {
    _ => fail("expected missing subcommand")
  }
  try expect_invocation(app.parse(argv=["group", "leaf"])).dispatch() catch {
    @cmder.CliError::MissingHandler("leaf") => ()
    error => raise error
  } noraise {
    _ => fail("expected missing handler")
  }
}

///|
test "host overrides create new values and provenance without editing the original" {
  let seen = Ref(0)
  let app = @cmder.cli(
    name="app",
    options=[
      @cmder.bool("quiet"),
      @cmder.int("count", default=1),
      @cmder.string("name", default="Ada"),
    ],
    positionals=[@cmder.positional("files")],
    run=ctx => seen.val = ctx.get_int_required("count"),
  )
  let call = expect_invocation(app.parse(argv=["--name", "Alice", "a.txt"]))
  let edited = call.with_overrides({
    "count": @cmder.ArgumentValue::Text("00000000000000000000000072"),
    "quiet": @cmder.ArgumentValue::Flag(true),
    "files": @cmder.ArgumentValue::Positionals(["b.txt", "c.txt"]),
  })
  assert_true(call.context.get_int("count") == Some(1))
  assert_true(call.source_of("count") == Some(@cmder.ValueSource::Default))
  assert_eq(call.context.get_strings("files"), ["a.txt"])
  assert_true(edited.context.get_int("count") == Some(72))
  assert_true(edited.context.get_bool("quiet"))
  assert_true(edited.source_of("count") == Some(@cmder.ValueSource::Override))
  assert_true(
    edited.context.source_of("quiet") == Some(@cmder.ValueSource::Override),
  )
  assert_false(edited.was_provided("count"))
  assert_true(edited.was_provided("name"))
  edited.dispatch()
  assert_eq(seen.val, 72)
  let again = edited.with_overrides({
    "count": @cmder.ArgumentValue::Integer(3),
    "quiet": @cmder.ArgumentValue::Flag(false),
  })
  again.dispatch()
  assert_eq(seen.val, 3)
  assert_false(again.context.get_bool("quiet"))
  let cleared = again.with_overrides({
    "files": @cmder.ArgumentValue::Positionals([]),
  })
  assert_eq(cleared.context.get_strings("files"), [])
  assert_true(cleared.source_of("files") is None)
}

///|
test "invalid host overrides are atomic and respect kinds and positional cardinality" {
  let app = @cmder.cli(
    name="app",
    options=[@cmder.int("count", default=1), @cmder.bool("quiet")],
    positionals=[
      @cmder.positional("source", required=true),
      @cmder.positional("destination"),
    ],
  )
  let call = expect_invocation(app.parse(argv=["a"]))
  for
    overrides in [
      {
        "count": @cmder.ArgumentValue::Integer(2),
        "unknown": @cmder.ArgumentValue::Text("x"),
      },
      { "count": @cmder.ArgumentValue::Text("bad") },
      { "count": @cmder.ArgumentValue::Text("2147483648") },
      { "quiet": @cmder.ArgumentValue::Integer(1) },
      { "source": @cmder.ArgumentValue::Positionals([]) },
      { "source": @cmder.ArgumentValue::Positionals(["a", "b"]) },
      { "source": @cmder.ArgumentValue::Text("a") },
    ] {
    try call.with_overrides(overrides) catch {
      _ => ()
    } noraise {
      _ => fail("expected invalid override")
    }
    assert_true(call.context.get_int("count") == Some(1))
    assert_true(call.source_of("count") == Some(@cmder.ValueSource::Default))
    assert_eq(call.context.get_strings("source"), ["a"])
  }
}

///|
test "root execution supports positionals examples and original errors" {
  let seen = Ref("")
  let app = @cmder.cli(
    name="copy",
    positionals=[@cmder.positional("source", required=true)],
    options=[@cmder.int("count", default=2)],
    examples=["copy input.txt"],
    run=ctx => seen.val = ctx.get_string_required("source"),
  )
  app.run(argv=["input.txt"])
  assert_eq(seen.val, "input.txt")
  assert_true(app.render_help().contains("copy input.txt"))
  assert_true(
    app.render_schema_json()
    is {
      "positionals": { "source": _, .. },
      "examples": ["copy input.txt"],
      ..
    },
  )
  let broken = @cmder.cli(name="broken", run=_ => {
    raise TestBusinessError::Denied("root")
  })
  try broken.run(argv=[]) catch {
    TestBusinessError::Denied("root") => ()
    error => raise error
  } noraise {
    _ => fail("expected root business error")
  }
}

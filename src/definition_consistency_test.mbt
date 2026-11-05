///|
fn expect_definition_error(build : () -> @cmder.CliApp raise) -> Unit raise {
  try build() catch {
    @cmder.CliError::InvalidDefinition(_) => ()
    error => raise error
  } noraise {
    _ => fail("expected invalid definition")
  }
}

///|
test "normalized defaults agree across parser help schema and examples" {
  let app = @cmder.cli(
    name="app",
    options=[
      @cmder.int("count", default=3, required=true, global=true),
      @cmder.bool("quiet", global=true),
    ],
    commands=[@cmder.command(name="go")],
  )
  let call = expect_invocation(app.parse(argv=["go"]))
  assert_true(call.context.get_int("count") == Some(3))
  assert_false(call.context.get_bool("quiet"))
  assert_false(app.render_help(command_path=["go"]).contains("[required]"))
  guard app.render_schema_json()
    is { "options": options, "examples": ["app"], .. } else {
    fail("expected root metadata")
  }
  json_inspect(options, content={
    "count": {
      "description": "",
      "required": false,
      "global": true,
      "type": "int",
      "default": 3,
    },
    "quiet": {
      "description": "",
      "required": false,
      "global": true,
      "type": "bool",
      "style": "flag",
    },
  })
}

///|
test "construction rejects duplicate argument names and short spellings" {
  expect_definition_error(() => {
    @cmder.cli(name="app", options=[@cmder.string("name"), @cmder.bool("name")])
  })
  expect_definition_error(() => {
    @cmder.cli(name="app", options=[
      @cmder.string("a", short='x'),
      @cmder.bool("b", short='x'),
    ])
  })
  expect_definition_error(() => {
    @cmder.cli(name="app", options=[@cmder.string("file")], positionals=[
      @cmder.positional("file"),
    ])
  })
  expect_definition_error(() => {
    @cmder.cli(name="app", commands=[
      @cmder.command(name="go"),
      @cmder.command(name="go"),
    ])
  })
  expect_definition_error(() => {
    @cmder.cli(name="app", commands=[@cmder.command(name="help")])
  })
}

///|
test "construction rejects invalid names and positional order in every branch" {
  for name in ["", "--bad", "two words", "a=b", "a\u0000b"] {
    expect_definition_error(() => {
      @cmder.cli(name="app", options=[@cmder.string(name)])
    })
  }
  expect_definition_error(() => {
    @cmder.cli(name="app", options=[@cmder.bool("quiet", short='\u0000')])
  })
  expect_definition_error(() => {
    @cmder.cli(name="app", commands=[
      @cmder.command(name="unused", positionals=[
        @cmder.positional("optional"),
        @cmder.positional("required", required=true),
      ]),
    ])
  })
}

///|
test "globals cannot be redefined or shadowed by descendants" {
  for
    child in [
      @cmder.string("count"),
      @cmder.int("count", global=true),
      @cmder.bool("other", short='c'),
    ] {
    expect_definition_error(() => {
      @cmder.cli(
        name="app",
        options=[@cmder.int("count", short='c', global=true)],
        commands=[@cmder.command(name="go", options=[child])],
      )
    })
  }
  expect_definition_error(() => {
    @cmder.cli(name="app", options=[@cmder.string("file", global=true)], commands=[
      @cmder.command(name="go", positionals=[@cmder.positional("file")]),
    ])
  })
  // Sibling-local names and aliases remain independent.
  ignore(
    @cmder.cli(name="app", commands=[
      @cmder.command(name="one", options=[@cmder.int("value", short='v')]),
      @cmder.command(name="two", options=[@cmder.string("value", short='v')]),
    ]),
  )
}

///|
test "construction rejects shell metacharacters and special option spellings" {
  for
    name in [
      "$(id)", "name;echo", "quote'", "back\\slash", "trailing-", "dot.name",
    ] {
    expect_definition_error(() => @cmder.cli(name~, run=_ => ()))
    expect_definition_error(() => {
      @cmder.cli(name="app", options=[@cmder.string(name)])
    })
    expect_definition_error(() => {
      @cmder.cli(name="app", commands=[@cmder.command(name~)])
    })
  }
  for short in ['$', '\'', '\\', '-', '[', ':', '\n'] {
    expect_definition_error(() => {
      @cmder.cli(name="app", options=[@cmder.bool("quiet", short~)])
    })
  }
}

///|
test "required positionals cannot make subcommands unreachable" {
  expect_definition_error(() => {
    @cmder.cli(
      name="app",
      positionals=[@cmder.positional("file", required=true)],
      commands=[@cmder.command(name="go")],
    )
  })
  expect_definition_error(() => {
    @cmder.cli(name="app", commands=[
      @cmder.command(
        name="group",
        positionals=[@cmder.positional("file", required=true)],
        subcommands=[@cmder.command(name="go")],
      ),
    ])
  })
  let root = Ref("")
  let child = Ref(false)
  let app = @cmder.cli(
    name="app",
    positionals=[@cmder.positional("files")],
    run=ctx => root.val = ctx.get_strings("files").join(","),
    commands=[@cmder.command(name="go", run=_ => child.val = true)],
  )
  app.run(argv=["input.txt"])
  assert_eq(root.val, "input.txt")
  app.run(argv=["go"])
  assert_true(child.val)
  assert_true(
    app.parse(argv=["input.txt", "go"])
    is Failed(@cmder.CliError::ParseError(_)),
  )
}

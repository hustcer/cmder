///|
test "defaulted public option records agree across parsing help schema and examples" {
  for
    option in [
      { ..@cmder.string("value", default=Some("Ada")), required: true, },
      { ..@cmder.int("value", default=Some(3)), required: true, },
    ] {
    let app = @cmder.cli(name="app", options=[option], commands=[
      @cmder.command(name="group", options=[option], subcommands=[
        @cmder.command(name="go", options=[option]),
      ]),
    ])
    let call = expect_invocation(app.parse(argv=["group", "go"]))
    assert_true(call.context.get_string("value") == option.default_value)
    let schema = app.render_schema_json()
    guard schema
      is {
        "options": { "value": { "required": false, .. }, .. },
        "commands": {
          "group": {
            "options": { "value": { "required": false, .. }, .. },
            "examples": ["app group"],
            "commands": {
              "go": {
                "options": { "value": { "required": false, .. }, .. },
                "examples": ["app group go"],
                ..
              },
              ..
            },
            ..
          },
          ..
        },
        ..
      } else {
      fail(schema.stringify())
    }
    guard app.parse(argv=["group", "go", "--help"]) is Help(help) else {
      fail("expected help")
    }
    assert_eq(help.trim(), app.render_help(command_path=["group", "go"]).trim())
    assert_false(help.contains("[required]"))
  }
}

///|
test "public boolean records remain optional flags without value defaults" {
  let option = {
    ..@cmder.bool("quiet"),
    required: true,
    default_value: Some("true"),
  }
  let app = @cmder.cli(name="app", commands=[
    @cmder.command(name="go", options=[option]),
  ])
  assert_false(
    expect_invocation(app.parse(argv=["go"])).context.get_bool("quiet"),
  )
  assert_true(
    expect_invocation(app.parse(argv=["go", "--quiet"])).context.get_bool(
      "quiet",
    ),
  )
  guard app.render_schema_json()
    is {
      "commands": {
        "go": {
          "options": { "quiet": metadata, .. },
          "examples": ["app go"],
          ..
        },
        ..
      },
      ..
    } else {
    fail("expected optional flag metadata and example")
  }
  json_inspect(metadata, content={
    "type": "bool",
    "description": "",
    "required": false,
    "style": "flag",
  })
}

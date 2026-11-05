///|
test "argparse interop converts immutable command definitions" {
  let cmd = @cmder.command(name="greet", description="Greet someone", options=[
    @cmder.string("name", short='n', required=true),
    @cmder.bool("verbose", short='v'),
    @cmder.int("count", default=1),
  ])
  let help = @cmder.build_command(cmd).render_help()
  for text in ["greet", "--name", "--verbose", "--count"] {
    assert_true(help.contains(text))
  }
}

///|
test "argparse interop preserves nested commands and global options" {
  let cmd = @cmder.command(
    name="app",
    options=[@cmder.string("profile", global=true)],
    subcommands=[@cmder.command(name="serve", options=[@cmder.int("port")])],
  )
  let parser = @cmder.build_command(cmd)
  assert_true(parser.render_help().contains("serve"))
  assert_true(
    parser.parse_outcome(argv=["serve", "--profile", "dev"]) is Parsed(_),
  )
}

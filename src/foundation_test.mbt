///|
test "execution errors have display-ready messages" {
  let app = @cmder.cli(name="app")
  try app.run(argv=Some([])) catch {
    err =>
      assert_eq(err.to_string(), "no command specified. Use --help for usage.")
  } noraise {
    _ => fail("expected a missing command error")
  }
}

///|
test "command help displays explicit examples" {
  let command = @cmder.command(name="copy", examples=[
    "app copy source.txt destination.txt",
  ])
  let help = @cmder.build_command(command).render_help()
  assert_true(help.contains("Examples:"))
  assert_true(help.contains("app copy source.txt destination.txt"))
}

///|
test "completions include parser builtins" {
  let app = @cmder.cli(name="app", commands=[@cmder.command(name="go")])
  let bash = app.render_bash_completion()
  assert_true(bash.contains("--help"))
  assert_true(bash.contains("--version"))
  let zsh = app.render_zsh_completion()
  assert_true(zsh.contains("--help"))
  assert_true(zsh.contains("--version"))
  let fish = app.render_fish_completion()
  assert_true(fish.contains("-l help"))
  assert_true(fish.contains("-l version"))
}

///|
test "builtin help and version spellings are shadowed independently" {
  let app = @cmder.cli(name="app", version="1.2.3", options=[
    @cmder.string("help", short='V'),
  ])
  assert_true(app.parse(argv=["-h"]) is Help(_))
  assert_true(app.parse(argv=["--version"]) is Version("1.2.3"))
  for argv in [["--help", "manual"], ["-V", "manual"]] {
    let value = expect_invocation(app.parse(argv~))
    assert_true(value.context.get_string("help") == Some("manual"))
  }
  let zsh = app.render_zsh_completion()
  assert_true(zsh.contains("'-V[]:value:' '--help[]:value:'"))
  assert_true(zsh.contains("'-h[Show help information.]'"))
  assert_true(zsh.contains("'--version[Show version information.]'"))
  assert_false(zsh.contains("'--help[Show help information.]'"))
  assert_false(zsh.contains("'-V[Show version information.]'"))
}

///|
test "command collections are detached from caller-owned arrays" {
  let options = [@cmder.string("name")]
  let children = [@cmder.command(name="child")]
  let examples = ["app child"]
  let root = @cmder.command(
    name="app",
    options~,
    subcommands=children,
    examples~,
  )
  options[0] = @cmder.int("different")
  children[0] = @cmder.command(name="different")
  examples[0] = "edited"
  assert_eq(root.options[0].name, "name")
  assert_eq(root.subcommands[0].name, "child")
  assert_eq(root.examples[0], "app child")
}

///|
test "application owns a single immutable root command" {
  let commands = [@cmder.command(name="go")]
  let app = @cmder.cli(name="app", version="2", commands~, positionals=[
    @cmder.positional("file"),
  ])
  commands[0] = @cmder.command(name="edited")
  assert_eq(app.root.name, "app")
  assert_eq(app.version, "2")
  assert_eq(app.root.subcommands[0].name, "go")
  assert_eq(app.root.positionals[0].name, "file")
}

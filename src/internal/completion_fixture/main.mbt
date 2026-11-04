///|
// A deterministic command tree consumed by the real-shell integration tests.
fn main {
  let app = @cmder.cli(
    name="cmder-test",
    options=[
      @cmder.bool("verbose", short='v'),
      @cmder.string("profile", short='p'),
    ],
    commands=[
      @cmder.command(name="db", options=[@cmder.string("region", short='r')], subcommands=[
        @cmder.command(name="inspect", options=[
          @cmder.bool("db-only"),
          @cmder.string("format", short='f'),
        ]),
      ]),
      @cmder.command(name="cache", subcommands=[
        @cmder.command(name="inspect", options=[@cmder.bool("cache-only")]),
      ]),
      @cmder.command(name="files", positionals=[@cmder.positional("paths")], options=[
        @cmder.bool("force"),
      ]),
    ],
  )
  let args = @env.args()
  match args[args.length() - 1] {
    "bash" => println(app.render_bash_completion())
    "zsh" => println(app.render_zsh_completion())
    "fish" => println(app.render_fish_completion())
    _ => panic()
  }
}

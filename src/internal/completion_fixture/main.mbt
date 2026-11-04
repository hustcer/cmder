///|
// A deterministic command tree consumed by the real-shell integration tests.
fn main {
  let app = @cmder.cli(
    name="cmder-test",
    version="1.2.3",
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
      @cmder.command(
        name="files",
        positionals=[@cmder.positional("paths")],
        options=[@cmder.bool("force")],
        examples=["cmder-test files a.txt"],
        run=Some(fn(ctx) {
          println("callback files: \{ctx.get_strings("paths").join(",")}")
        }),
      ),
      @cmder.command(name="custom-help", options=[@cmder.string("help")]),
      @cmder.command(name="custom-short", options=[
        @cmder.string("host", short='h'),
      ]),
    ],
  )
  let args = @env.args()
  match args[args.length() - 1] {
    "bash" => println(app.render_bash_completion())
    "zsh" => println(app.render_zsh_completion())
    "fish" => println(app.render_fish_completion())
    "parse-help" => {
      guard app.parse(argv=["files", "--help"]) is Help(text) else { panic() }
      println(text)
      println("returned to host")
    }
    "parse-version" => {
      guard app.parse(argv=["--version"]) is Version(text) else { panic() }
      println(text)
      println("returned to host")
    }
    "parse-error" => {
      guard app.parse(argv=["--unknown"]) is Failed(error) else { panic() }
      println(error.message())
      println("returned to host")
    }
    _ => {
      app.run() catch {
        err => {
          println(err)
          return
        }
      }
      println("returned from run")
    }
  }
}

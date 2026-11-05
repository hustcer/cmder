///|
suberror FixtureError {
  Rejected
}

///|
// A deterministic command tree consumed by the real-shell integration tests.
fn main raise {
  let app = @cmder.cli(
    name="cmder-test",
    version="1.2.3",
    options=[
      @cmder.bool("verbose", short='v'),
      @cmder.string("profile", short='p'),
      @cmder.bool("trace", global=true),
    ],
    positionals=[@cmder.positional("inputs")],
    run=ctx => {
      let inputs = ctx.get_strings("inputs")
      if inputs == ["reject"] {
        raise FixtureError::Rejected
      }
      println("callback root: \{inputs.join(",")}")
    },
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
        run=ctx => {
          if ctx.get_bool("trace") {
            println("trace enabled")
          }
          println("callback files: \{ctx.get_strings("paths").join(",")}")
        },
      ),
      @cmder.command(name="custom-help", options=[@cmder.string("help")]),
      @cmder.command(name="custom-short", options=[
        @cmder.string("host", short='h'),
      ]),
      @cmder.command(
        name="quoting",
        description="\\';echo cmder-description;# [x]: [y]: 'again' \\",
        options=[
          @cmder.string(
            "value",
            description="\\';echo cmder-description;# [x]: [y]: 'again' \\",
          ),
          @cmder.bool("lines", description="first\nsecond"),
        ],
      ),
    ],
  )
  let args = @env.args()
  match args[args.length() - 1] {
    "bash" => println(app.render_bash_completion())
    "zsh" => println(app.render_zsh_completion())
    "fish" => println(app.render_fish_completion())
    "bash-names" | "zsh-names" | "fish-names" =>
      println(name_completions(args[args.length() - 1]))
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
    "exit-reject" => {
      app.run_or_exit(argv=["reject"])
      println("unexpected return from run_or_exit")
    }
    _ => {
      app.run() catch {
        err => {
          eprintln(err)
          @env.exit(1)
        }
      }
      println("returned from run")
    }
  }
}

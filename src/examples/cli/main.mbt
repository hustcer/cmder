///|
fn main raise {
  let app = @cmder.cli(
    name="myapp",
    version="0.1.0",
    description="Example CLI with nested subcommands",
    commands=[
      @cmder.command(
        name="greet",
        description="Greet someone",
        options=[
          @cmder.string(
            "name",
            short='n',
            description="Name to greet",
            required=true,
          ),
          @cmder.bool("loud", short='l', description="Shout the greeting"),
          @cmder.int("count", short='c', description="Repeat count", default=1),
        ],
        examples=[
          "myapp greet --name Alice", "myapp greet --name Bob --loud --count 3",
        ],
        run=ctx => {
          let name = ctx.get_string_required("name")
          let loud = ctx.get_bool("loud")
          let count = ctx.get_int("count")
          let count = count.unwrap_or(1)
          for _ in 0..<count {
            let msg = "Hello, \{name}!"
            if loud {
              println(msg.to_upper())
            } else {
              println(msg)
            }
          }
        },
      ),
      @cmder.command(name="db", description="Database commands", subcommands=[
        @cmder.command(name="migrate", description="Run database migrations", subcommands=[
          @cmder.command(
            name="up",
            description="Apply pending migrations",
            options=[
              @cmder.bool("dry-run", description="Preview without applying"),
              @cmder.int(
                "steps",
                short='s',
                description="Number of migrations to apply",
              ),
            ],
            examples=[
              "myapp db migrate up", "myapp db migrate up --dry-run", "myapp db migrate up --steps 5",
            ],
            run=ctx => {
              let dry = ctx.get_bool("dry-run")
              let steps = ctx.get_int("steps")
              if dry {
                println("[DRY RUN] Would apply migrations")
              } else {
                match steps {
                  Some(n) => println("Applying \{n} migrations...")
                  None => println("Applying all pending migrations...")
                }
              }
              println("Done.")
            },
          ),
          @cmder.command(
            name="down",
            description="Rollback migrations",
            options=[
              @cmder.int(
                "steps",
                short='s',
                description="Number of migrations to rollback",
                default=1,
              ),
            ],
            run=ctx => {
              let steps = ctx.get_int("steps")
              let steps = steps.unwrap_or(1)
              println("Rolling back \{steps} migration(s)...")
              println("Done.")
            },
          ),
        ]),
        @cmder.command(
          name="seed",
          description="Seed the database",
          options=[
            @cmder.string(
              "file",
              short='f',
              description="Seed file path",
              default="seeds/default.sql",
            ),
          ],
          run=ctx => {
            let file = ctx.get_string("file").unwrap_or("seeds/default.sql")
            println("Seeding from: \{file}")
          },
        ),
      ]),
    ],
  )
  // --schema flag: output structured JSON and exit
  let args = @env.args()
  if args.length() > 0 && args[args.length() - 1] == "--schema" {
    println(app.render_schema())
    return
  }
  app.run() catch {
    err => {
      eprintln(err)
      @env.exit(1)
    }
  }
}

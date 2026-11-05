///|
/// Defines a local positional argument. The final positional accepts multiple
/// values; earlier positionals accept at most one. Declare required ones first.
pub fn positional(
  name : String,
  description~ : String = "",
  required~ : Bool = false,
) -> PositionalDef {
  { name, description, required, }
}

///|
/// Defines an immutable command. Input collections are copied. Callback errors
/// propagate unchanged to the application host.
///
/// ```mbt check
/// test {
///   let cmd = @cmder.command(name="go", run=_ => ())
///   inspect(cmd.name, content="go")
/// }
/// ```
pub fn command(
  name~ : String,
  description~ : String = "",
  options~ : ArrayView[OptionDef] = [],
  positionals~ : ArrayView[PositionalDef] = [],
  examples~ : ArrayView[String] = [],
  subcommands~ : ArrayView[CommandDef] = [],
  run? : (Context) -> Unit raise,
) -> CommandDef {
  {
    name,
    description,
    options: ReadOnlyArray::from_array(options),
    positionals: ReadOnlyArray::from_array(positionals),
    examples: ReadOnlyArray::from_array(examples),
    subcommands: ReadOnlyArray::from_array(subcommands),
    run,
  }
}

///|
/// Builds and validates an immutable application. Root commands support the
/// same options, positionals, examples and raising callbacks as subcommands.
/// Only explicitly global options are shared with descendants.
///
/// ```mbt check
/// test {
///   let count = Ref(0)
///   let app = @cmder.cli(name="demo", options=[@cmder.int("count", default=2)], run=ctx => {
///     count.val = ctx.get_int_required("count")
///   })
///   app.run(argv=[])
///   assert_eq(count.val, 2)
/// }
/// ```
pub fn cli(
  name~ : String,
  version~ : String = "0.0.0",
  description~ : String = "",
  options~ : ArrayView[OptionDef] = [],
  positionals~ : ArrayView[PositionalDef] = [],
  examples~ : ArrayView[String] = [],
  commands~ : ArrayView[CommandDef] = [],
  run? : (Context) -> Unit raise,
) -> CliApp raise CliError {
  let root = command(
    name~,
    description~,
    options~,
    positionals~,
    examples~,
    subcommands=commands,
    run?,
  )
  validate_definition(root, [], [])
  { root, version, }
}

///|
fn find_command_def(
  commands : ArrayView[CommandDef],
  name : String,
) -> CommandDef? {
  commands.iter().find_first(cmd => cmd.name == name)
}

///|
/// Executes the command bound during parsing with this invocation's context.
/// It performs no parsing, output or process exit. Callback errors propagate
/// unchanged. Each call deliberately executes again. Host overrides must be
/// applied with with_overrides, which returns another validated invocation.
///
/// ```mbt check
/// test {
///   let called = Ref(false)
///   let app = @cmder.cli(name="demo", run=_ => called.val = true)
///   guard app.parse(argv=[]) is Parsed(call) else { fail("parse") }
///   assert_false(called.val)
///   call.dispatch()
///   assert_true(called.val)
/// }
/// ```
pub fn Invocation::dispatch(self : Invocation) -> Unit raise {
  match self.selected.run {
    Some(callback) => callback(self.context)
    None => {
      if self.command_path.is_empty() {
        raise CliError::MissingCommand
      }
      if self.selected.subcommands.is_empty() {
        raise CliError::MissingHandler(self.selected.name)
      }
      raise CliError::MissingSubcommand(
        self.selected.name,
        [
          for cmd in self.selected.subcommands => cmd.name
        ],
      )
    }
  }
}

///|
#cfg(target="js")
fn process_argv() -> ArrayView[String] {
  match @env.args() {
    [_, _, .. rest] => rest
    _ => []
  }
}

///|
#cfg(not(target="js"))
fn process_argv() -> ArrayView[String] {
  match @env.args() {
    [_, .. rest] => rest
    [] => []
  }
}

///|
/// Parses and dispatches, propagating parser and original callback errors.
/// Omit argv to use process arguments. Help and version print and exit with
/// status zero. Embedded hosts can use parse and Invocation::dispatch instead.
pub fn CliApp::run(self : CliApp, argv? : ArrayView[String]) -> Unit raise {
  let args = argv.unwrap_or_else(process_argv)
  match self.parse(argv=args) {
    Parsed(call) => call.dispatch()
    Help(text) | Version(text) => {
      println(text)
      @env.exit(0)
    }
    Failed(error) => raise error
  }
}

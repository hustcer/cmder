///|
/// Defines a positional argument. The final positional accepts multiple values;
/// earlier positionals accept at most one. Declare required arguments first.
///
/// ```mbt check
/// test {
///   let file = @cmder.positional("file", required=true)
///   assert_true(file.required)
/// }
/// ```
pub fn positional(
  name : String,
  description~ : String = "",
  required~ : Bool = false,
) -> PositionalDef {
  { name, description, required, }
}

///|
/// Defines a command with options, positionals, subcommands, and a callback.
///
/// ```mbt check
/// test {
///   let greet = @cmder.command(name="greet", options=[@cmder.string("name")])
///   inspect(greet.name, content="greet")
/// }
/// ```
pub fn command(
  name~ : String,
  description~ : String = "",
  options~ : Array[OptionDef] = [],
  positionals~ : Array[PositionalDef] = [],
  examples~ : Array[String] = [],
  subcommands~ : Array[CommandDef] = [],
  run~ : ((Context) -> Unit)? = None,
) -> CommandDef {
  { name, description, options, positionals, examples, subcommands, run, }
}

///|
/// Creates an application. Ancestor values are available to callbacks;
/// values at a descendant level, including defaults, take precedence by name.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="demo", commands=[@cmder.command(name="hello")])
///   inspect(app.name, content="demo")
/// }
/// ```
pub fn cli(
  name~ : String,
  version~ : String = "0.0.0",
  description~ : String = "",
  options~ : Array[OptionDef] = [],
  commands~ : Array[CommandDef] = [],
) -> CliApp {
  { name, version, description, root_options: options, commands, }
}

///|
fn find_command_def(commands : Array[CommandDef], name : String) -> CommandDef? {
  for cmd in commands {
    if cmd.name == name {
      return Some(cmd)
    }
  }
  None
}

///|
fn inherit_context(parent : Context, child : Context) -> Context {
  let flags = parent.flags.copy()
  let values = parent.values.copy()
  for name, value in child.flags {
    values.remove(name)
    flags[name] = value
  }
  for name, value in child.values {
    flags.remove(name)
    values[name] = value
  }
  { flags, values, subcommand: child.subcommand, }
}

///|
fn execute_command(
  app : CliApp,
  invocation : Invocation,
) -> Unit raise CliError {
  if invocation.command_path.is_empty() {
    raise CliError::MissingCommand
  }
  guard find_command_path(app.commands, invocation.command_path) is Some(cmd) else {
    raise CliError::UnknownCommand(invocation.command_path)
  }
  match cmd.run {
    Some(callback) => callback(invocation.context)
    None =>
      if cmd.subcommands.is_empty() {
        raise CliError::MissingHandler(cmd.name)
      } else {
        raise CliError::MissingSubcommand(
          cmd.name,
          cmd.subcommands.map(c => c.name),
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
/// Parses arguments and executes the selected command's callback.
/// Omit `argv` to read process arguments. Help and version print and exit with
/// status 0, preserving the convenience API. Use parse for side-effect-free
/// handling. Callback signatures and closest-value precedence are unchanged.
/// Parse failures raise CliError::ParseError with the original diagnostic;
/// missing command, subcommand, or callback errors have distinct CliError cases.
///
/// ```mbt check
/// test {
///   let called = Ref(false)
///   let app = @cmder.cli(name="demo", commands=[
///     @cmder.command(name="go", run=Some(fn(_) { called.val = true })),
///   ])
///   app.run(argv=Some(["go"]))
///   assert_true(called.val)
/// }
/// ```
pub fn CliApp::run(self : CliApp, argv~ : Array[String]? = None) -> Unit raise {
  let args = match argv {
    Some(args) => args[:]
    None => process_argv()
  }
  match self.parse(argv=args) {
    Parsed(invocation) => execute_command(self, invocation)
    Help(text) | Version(text) => {
      println(text)
      @env.exit(0)
    }
    Failed(error) => raise error
  }
}

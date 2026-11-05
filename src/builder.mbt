///|
fn build_option_to_flag(opt : OptionDef) -> @argparse.FlagArg {
  @argparse.FlagArg(
    opt.name,
    short?=opt.short,
    about=opt.description,
    global=opt.global,
  )
}

///|
fn build_option_to_option_arg(opt : OptionDef) -> @argparse.OptionArg {
  let defaults = option_default(opt).map(value => [value]).unwrap_or([])
  @argparse.OptionArg(
    opt.name,
    short?=opt.short,
    about=opt.description,
    default_values=defaults,
    required=opt.required,
    global=opt.global,
    allow_hyphen_values=opt.kind is IntOpt(_),
  )
}

///|
fn build_positional(pos : PositionalDef, last : Bool) -> @argparse.PositionArg {
  let lower = if pos.required { 1 } else { 0 }
  let range = if last {
    @argparse.ValueRange(lower~)
  } else {
    @argparse.ValueRange(lower~, upper=1)
  }
  @argparse.PositionArg(pos.name, about=pos.description, num_args=range)
}

///|
fn command_about(cmd : CommandDef) -> String {
  if cmd.examples.is_empty() {
    return cmd.description
  }
  let examples = "Examples:\n  \{cmd.examples.join("\n  ")}"
  if cmd.description == "" {
    examples
  } else {
    "\{cmd.description}\n\n\{examples}"
  }
}

///|
fn build_parser(cmd : CommandDef, version? : String) -> @argparse.Command {
  let flags : Array[@argparse.FlagArg] = []
  let options : Array[@argparse.OptionArg] = []
  for opt in cmd.options {
    match opt.kind {
      BoolOpt => flags.push(build_option_to_flag(opt))
      StringOpt(_) | IntOpt(_) => options.push(build_option_to_option_arg(opt))
    }
  }
  let positionals = cmd.positionals.mapi((i, pos) => {
    build_positional(pos, i == cmd.positionals.length() - 1)
  })
  let subcommands = cmd.subcommands.map(sub => build_parser(sub))
  @argparse.Command(
    cmd.name,
    about=command_about(cmd),
    version?=version.map(v => v[:]),
    flags~,
    options~,
    positionals~,
    subcommands~,
  )
}

///|
fn build_cli_command(app : CliApp) -> @argparse.Command {
  build_parser(app.root, version=app.version)
}

///|
/// Explicit argparse interop. Validates definitions and builds the underlying
/// parser, without cmder's integer checks or callback execution. Normal consumers
/// should use CliApp::parse instead.
pub fn build_command(cmd : CommandDef) -> @argparse.Command raise CliError {
  validate_definition(cmd, [], [])
  build_parser(cmd)
}

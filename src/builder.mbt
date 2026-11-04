///|
fn has_short(opt : OptionDef) -> Bool {
  opt.short != no_short
}

///|
fn build_option_to_flag(opt : OptionDef) -> @argparse.FlagArg {
  if has_short(opt) {
    @argparse.FlagArg(opt.name, short=opt.short, about=opt.description)
  } else {
    @argparse.FlagArg(opt.name, about=opt.description)
  }
}

///|
fn build_option_to_option_arg(opt : OptionDef) -> @argparse.OptionArg {
  let short = if has_short(opt) { Some(opt.short) } else { None }
  let default_values = match opt.default_value {
    Some(value) => [value]
    None => []
  }
  @argparse.OptionArg(
    opt.name,
    short?,
    about=opt.description,
    default_values~,
    required=opt.required && opt.default_value is None,
    allow_hyphen_values=opt.type_ == IntOpt,
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
fn build_cli_command(app : CliApp) -> @argparse.Command {
  let flags : Array[@argparse.FlagArg] = []
  let options : Array[@argparse.OptionArg] = []
  for opt in app.root_options {
    match opt.type_ {
      BoolOpt => flags.push(build_option_to_flag(opt))
      StringOpt | IntOpt => options.push(build_option_to_option_arg(opt))
    }
  }
  @argparse.Command(
    app.name,
    about=app.description,
    version=app.version,
    flags~,
    options~,
    subcommands=app.commands.map(build_command),
  )
}

///|
/// Converts a command definition into an `argparse.Command`. Explicit examples
/// are included in its help description; callback execution is not attached.
///
/// ```mbt check
/// test {
///   let command = @cmder.command(name="greet")
///   let parser = @cmder.build_command(command)
///   assert_true(parser.render_help().contains("greet"))
/// }
/// ```
pub fn build_command(cmd : CommandDef) -> @argparse.Command {
  let flags : Array[@argparse.FlagArg] = []
  let options : Array[@argparse.OptionArg] = []
  for opt in cmd.options {
    match opt.type_ {
      BoolOpt => flags.push(build_option_to_flag(opt))
      StringOpt | IntOpt => options.push(build_option_to_option_arg(opt))
    }
  }
  let positionals = cmd.positionals.mapi(fn(i, p) {
    build_positional(p, i == cmd.positionals.length() - 1)
  })
  let subcommands = cmd.subcommands.map(fn(sub) { build_command(sub) })
  @argparse.Command(
    cmd.name,
    about=command_about(cmd),
    flags~,
    options~,
    positionals~,
    subcommands~,
  )
}

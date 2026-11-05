///|
priv enum ParserMode {
  Interop
  Invocation
  Help
}

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
fn build_option_to_option_arg(
  opt : OptionDef,
  defer_local_required : Bool,
) -> @argparse.OptionArg {
  let defaults = option_default(opt).map(value => [value]).unwrap_or([])
  @argparse.OptionArg(
    opt.name,
    short?=opt.short,
    about=opt.description,
    default_values=defaults,
    required=opt.required && (!defer_local_required || opt.global),
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
fn command_about(cmd : CommandDef, mode : ParserMode) -> String {
  let parts : Array[String] = []
  if !cmd.description.is_empty() {
    parts.push(cmd.description)
  }
  let scope_note = match mode {
    Interop => false
    Help | Invocation => true
  }
  if scope_note && !cmd.subcommands.is_empty() {
    let locals = cmd.options.filter(opt => opt.required && !opt.global)
    if !locals.is_empty() {
      let names = locals.map(opt => "--\{opt.name}").join(", ")
      parts.push(
        "Local required options (\{names}) apply only to this command's own execution. Subcommands require their own local options and inherited globals.",
      )
    }
  }
  if !cmd.examples.is_empty() {
    parts.push("Examples:\n  \{cmd.examples.join("\n  ")}")
  }
  parts.join("\n\n")
}

///|
fn build_parser(
  cmd : CommandDef,
  version? : String,
  mode~ : ParserMode = Help,
) -> @argparse.Command {
  let flags : Array[@argparse.FlagArg] = []
  let options : Array[@argparse.OptionArg] = []
  for opt in cmd.options {
    match opt.kind {
      BoolOpt => flags.push(build_option_to_flag(opt))
      StringOpt(_) | IntOpt(_) =>
        options.push(build_option_to_option_arg(opt, mode is Invocation))
    }
  }
  let positionals = cmd.positionals.mapi((i, pos) => {
    build_positional(pos, i == cmd.positionals.length() - 1)
  })
  let subcommands = cmd.subcommands.map(sub => build_parser(sub, mode~))
  @argparse.Command(
    cmd.name,
    about=command_about(cmd, mode),
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
/// parser with argparse's ancestor-required semantics, without cmder's selected-
/// local required checks, integer checks or callback execution. Normal consumers
/// should use CliApp::parse instead.
pub fn build_command(cmd : CommandDef) -> @argparse.Command raise CliError {
  validate_definition(cmd, [], [])
  build_parser(cmd, mode=Interop)
}

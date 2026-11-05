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
  defer_required : Bool,
) -> @argparse.OptionArg {
  let defaults = option_default(opt).map(value => [value]).unwrap_or([])
  @argparse.OptionArg(
    opt.name,
    short?=opt.short,
    about=opt.description,
    default_values=defaults,
    required=opt.required && !defer_required,
    global=opt.global,
    allow_hyphen_values=opt.kind is IntOpt(_) && !defer_required,
  )
}

///|
fn positional_is_multiple(
  pos : PositionalDef,
  index : Int32,
  total : Int32,
) -> Bool {
  pos.multiple && index == total - 1
}

///|
fn build_positional(
  pos : PositionalDef,
  multiple : Bool,
  defer_required : Bool,
) -> @argparse.PositionArg {
  let lower = if pos.required && !defer_required { 1 } else { 0 }
  let range = if multiple {
    @argparse.ValueRange(lower~)
  } else {
    @argparse.ValueRange(lower~, upper=1)
  }
  @argparse.PositionArg(pos.name, about=pos.description, num_args=range)
}

///|
fn build_parser(
  cmd : CommandDef,
  version? : String,
  defer_required~ : Bool = false,
) -> @argparse.Command {
  let flags : Array[@argparse.FlagArg] = []
  let options : Array[@argparse.OptionArg] = []
  for opt in cmd.options {
    match opt.kind {
      BoolOpt => flags.push(build_option_to_flag(opt))
      StringOpt(_) | IntOpt(_) =>
        options.push(build_option_to_option_arg(opt, defer_required))
    }
  }
  let positionals = cmd.positionals.mapi((i, pos) => {
    build_positional(
      pos,
      positional_is_multiple(pos, i, cmd.positionals.length()),
      defer_required,
    )
  })
  let subcommands = cmd.subcommands.map(sub => {
    build_parser(sub, defer_required~)
  })
  @argparse.Command(
    cmd.name,
    about=cmd.description,
    version?=version.map(v => v[:]),
    flags~,
    options~,
    positionals~,
    subcommands~,
  )
}

///|
/// Explicit argparse interop. Validates definitions and builds the underlying
/// parser with argparse's ancestor-required semantics, without cmder's selected-
/// local required checks, integer checks or callback execution. Normal consumers
/// should use CliApp::parse instead.
///
/// ```mbt check
/// test {
///   let parser = @cmder.build_command(@cmder.command(name="go"))
///   assert_true(parser.render_help().has_prefix("Usage: go"))
/// }
/// ```
pub fn build_command(cmd : CommandDef) -> @argparse.Command raise CliError {
  validate_definition(cmd, [], [])
  let description = if cmd.examples.is_empty() {
    cmd.description
  } else {
    "\{cmd.description}\n\nExamples:\n  \{cmd.examples.join("\n  ")}"
  }
  build_parser({ ..cmd, description, })
}

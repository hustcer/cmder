///|
// Completion-only projection. Optional spellings model argparse's independently
// shadowable builtin long and short flags without changing public OptionDef.
priv struct CompletionOption {
  long : String?
  short : Char?
  description : String
  takes_value : Bool
}

///|
priv struct CompletionCommand {
  name : String
  description : String
  options : Array[CompletionOption]
  subcommands : Array[CompletionCommand]
}

///|
fn builtin_completion_options(
  options : ArrayView[OptionDef],
  version : Bool,
) -> Array[CompletionOption] {
  let builtins : Array[CompletionOption] = []
  fn add_builtin(name, short, description) {
    let long = if options.any(opt => opt.name == name) {
      None
    } else {
      Some(name)
    }
    let short = if options.iter().any(opt => opt.short == Some(short)) {
      None
    } else {
      Some(short)
    }
    if long is Some(_) || short is Some(_) {
      builtins.push({ long, short, description, takes_value: false, })
    }
  }
  add_builtin("help", 'h', "Show help information.")
  if version {
    add_builtin("version", 'V', "Show version information.")
  }
  builtins
}

///|
fn completion_options(
  options : ArrayView[OptionDef],
  version~ : Bool = false,
) -> Array[CompletionOption] {
  let projected = options.map(opt => CompletionOption::{
    long: Some(opt.name),
    short: opt.short,
    description: opt.description,
    takes_value: opt.kind != BoolOpt,
  })
  projected + builtin_completion_options(options, version)
}

///|
fn completion_help_targets(
  commands : ArrayView[CommandDef],
  help_options : Array[CompletionOption],
) -> Array[CompletionCommand] {
  commands.map(cmd => CompletionCommand::{
    name: cmd.name,
    description: cmd.description,
    options: help_options,
    subcommands: completion_help_targets(cmd.subcommands, help_options),
  })
}

///|
fn completion_commands(
  commands : ArrayView[CommandDef],
  options : ArrayView[OptionDef],
  inherited~ : ArrayView[OptionDef] = [],
) -> Array[CompletionCommand] {
  let globals = inherited.to_owned() + options.filter(opt => opt.global)
  let projected = commands.map(cmd => CompletionCommand::{
    name: cmd.name,
    description: cmd.description,
    options: completion_options(globals + cmd.options[:].to_owned()),
    subcommands: completion_commands(
      cmd.subcommands,
      cmd.options,
      inherited=globals,
    ),
  })
  if !commands.is_empty() {
    // `help` traverses command names, not application options. Its optional
    // trailing help flags belong to the command where the help verb occurred.
    let help_options = builtin_completion_options(
      inherited.to_owned() + options.to_owned(),
      false,
    )
    projected.push({
      name: "help",
      description: "Print help for the subcommand(s).",
      options: help_options,
      subcommands: completion_help_targets(commands, help_options),
    })
  }
  projected
}

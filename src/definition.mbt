///|
fn valid_name_char(c : Char) -> Bool {
  c is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_' | '-')
}

///|
fn check_name(name : String, description : String) -> Unit raise CliError {
  if name.is_empty() ||
    name.has_prefix("-") ||
    name.has_suffix("-") ||
    !name.iter().all(valid_name_char) {
    raise CliError::InvalidDefinition("\{description}: invalid name '\{name}'")
  }
}

///|
fn validate_definition(
  cmd : CommandDef,
  ancestors : ArrayView[String],
  globals : ArrayView[OptionDef],
) -> Unit raise CliError {
  let path = ancestors.to_owned()
  path.push(cmd.name)
  let scope = path.join(" ")
  check_name(cmd.name, "command")
  let names : Map[String, Bool] = Map([])
  let shorts : Map[Char, Bool] = Map([])
  let next_globals = globals.to_owned()
  for option in globals {
    names[option.name] = true
    if option.short is Some(short) {
      shorts[short] = true
    }
  }
  for option in cmd.options {
    check_name(option.name, scope)
    if names.contains(option.name) {
      raise CliError::InvalidDefinition(
        "\{scope}: duplicate or inherited global argument '\{option.name}'",
      )
    }
    names[option.name] = true
    if option.short is Some(short) {
      if short == '-' || !valid_name_char(short) {
        raise CliError::InvalidDefinition("\{scope}: invalid short option")
      }
      if shorts.contains(short) {
        raise CliError::InvalidDefinition(
          "\{scope}: duplicate or inherited global short option '-\{short}'",
        )
      }
      shorts[short] = true
    }
    if option.global {
      next_globals.push(option)
    }
  }
  let mut optional_seen = false
  for positional in cmd.positionals {
    check_name(positional.name, scope)
    if names.contains(positional.name) {
      raise CliError::InvalidDefinition(
        "\{scope}: duplicate or inherited global argument '\{positional.name}'",
      )
    }
    names[positional.name] = true
    if positional.required && optional_seen {
      raise CliError::InvalidDefinition(
        "\{scope}: required positionals must precede optional positionals",
      )
    }
    optional_seen = optional_seen || !positional.required
  }
  if !cmd.subcommands.is_empty() && cmd.positionals.any(pos => pos.required) {
    raise CliError::InvalidDefinition(
      "\{scope}: required positionals cannot be combined with subcommands",
    )
  }
  let commands : Map[String, Bool] = Map([])
  for sub in cmd.subcommands {
    if sub.name == "help" || commands.contains(sub.name) {
      raise CliError::InvalidDefinition(
        "\{scope}: duplicate or reserved subcommand '\{sub.name}'",
      )
    }
    commands[sub.name] = true
    validate_definition(sub, path, next_globals)
  }
}

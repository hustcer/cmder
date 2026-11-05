///|
// Return a value option only when its value is not already attached. Boolean
// short clusters may precede the option; the first value option consumes the rest.
fn pending_value_option(
  token : String,
  options : ArrayView[OptionDef],
) -> OptionDef? {
  if token.has_prefix("--") {
    if token.contains("=") {
      return None
    }
    let name = token[2:].to_owned()
    return options
      .iter()
      .find_first(option => option.name == name && option.kind != BoolOpt)
  }
  if !token.has_prefix("-") || token == "-" {
    return None
  }
  for index in 1..<token.length() {
    guard options
      .iter()
      .find_first(option => {
        option.short
        .map(short => short.to_int() == token[index].to_int())
        .unwrap_or(false)
      })
      is Some(option) else {
      return None
    }
    if option.kind != BoolOpt {
      return if index == token.length() - 1 { Some(option) } else { None }
    }
  }
  None
}

///|
fn builtin_help_token(token : String, options : ArrayView[OptionDef]) -> Bool {
  if token.has_prefix("--") {
    return token == "--help" && !options.any(option => option.name == "help")
  }
  if !token.has_prefix("-") {
    return false
  }
  for unit in token[1:].iter() {
    let option = options.iter().find_first(option => option.short == Some(unit))
    if unit == 'h' && option is None {
      return true
    }
    guard option is Some({ kind: BoolOpt, .. }) else { return false }
  }
  false
}

///|
// Argparse's allow_hyphen_values consumes every following flag. Attach only
// negative numeric spellings instead, leaving flags and `--` as parser tokens.
// Track value consumption and scope so reused local spellings remain independent.
fn normalize_integer_argv(
  root : CommandDef,
  argv : ArrayView[String],
) -> Array[String] {
  let result : Array[String] = []
  for index = 0, command = root, globals = [], positional = false; index <
     argv.length(); {
    let token = argv[index]
    if token == "--" || (token == "help" && !command.subcommands.is_empty()) {
      result.append(argv[index:])
      break
    }
    let options = globals + command.options[:].to_owned()
    if pending_value_option(token, options) is Some(option) &&
      index + 1 < argv.length() {
      let value = argv[index + 1]
      if option.kind is IntOpt(_) {
        if builtin_help_token(value, options) {
          // A pending integer must not consume an actual help request.
          // Supply a help-only placeholder so argparse still detects duplicate
          // occurrences and invalid short clusters before the help request.
          result.push("\{token}=0")
          result.push(value)
          continue index + 2, command, globals, positional
        }
        if value.length() > 1 && value[0] == '-' && value[1] is ('0'..<='9') {
          result.push("\{token}=\{value}")
          continue index + 2, command, globals, positional
        }
      }
      if !value.has_prefix("-") || value == "-" {
        result.push(token)
        result.push(value)
        continue index + 2, command, globals, positional
      }
    }
    result.push(token)
    if !token.has_prefix("-") {
      if !positional &&
        find_command_def(command.subcommands, token) is Some(child) {
        continue index + 1, child, inherited_options(globals, command), false
      }
      continue index + 1, command, globals, true
    }
    continue index + 1, command, globals, positional
  }
  result
}

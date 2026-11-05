///|
fn validate_option_types(
  options : ArrayView[OptionDef],
  matches : @argparse.Matches,
) -> Unit raise CliError {
  for option in options {
    if option.kind is IntOpt(_) {
      for value in matches.values.get(option.name).unwrap_or([]) {
        ignore(parse_integer_value(option.name, value))
      }
    }
  }
}

///|
fn invocation_from_matches(
  app : CliApp,
  matches : @argparse.Matches,
) -> Invocation raise CliError {
  let path : Array[String] = []
  let (selected, current, globals) = for command = app.root, current = matches, globals = [] {
    guard current.subcommand is Some((name, child)) else {
      break (command, current, globals)
    }
    // Reject explicitly supplied locals instead of silently discarding them.
    for option in command.options {
      if !option.global &&
        current.sources.get(option.name) is Some(@argparse.ValueSource::Argv) {
        raise CliError::UnexpectedLocalArgument(
          command=([app.root.name] + path).join(" "),
          name=option.name,
        )
      }
    }
    path.push(name)
    guard find_command_def(command.subcommands, name) is Some(child_command) else {
      raise CliError::UnknownCommand(path)
    }
    continue child_command, child, inherited_options(globals, command)
  }
  let visible = globals + selected.options[:].to_owned()
  for option in visible {
    if option.required && !current.values.contains(option.name) {
      raise CliError::MissingOption(option.name)
    }
  }
  for pos in selected.positionals {
    if pos.required && current.values.get(pos.name).unwrap_or([]).is_empty() {
      raise CliError::MissingPositional(pos.name)
    }
  }
  validate_option_types(visible, current)
  let specs : Map[String, ArgumentSpec] = Map([])
  for option in visible {
    specs[option.name] = Option(option)
  }
  for index, pos in selected.positionals {
    specs[pos.name] = Positional(
      pos,
      multiple=positional_is_multiple(pos, index, selected.positionals.length()),
    )
  }
  let flags : Map[String, Bool] = Map([])
  let values : Map[String, Array[String]] = Map([])
  let sources : Map[String, ValueSource] = Map([])
  for name, _ in specs {
    if current.flags.get(name) is Some(value) {
      flags[name] = value
    }
    if current.values.get(name) is Some(value) {
      values[name] = value.copy()
    }
    if current.sources.get(name) is Some(source) {
      sources[name] = match source {
        @argparse.ValueSource::Argv => Argv
        @argparse.ValueSource::Env => Env
        @argparse.ValueSource::Default => Default
      }
    }
  }
  {
    command_path: ReadOnlyArray::from_array(path),
    context: { flags, values, sources, specs, },
    selected,
  }
}

///|
/// Parses explicit argv without process I/O or callbacks. Structural failures
/// and help/version precede cmder validation. Explicit ancestor-local options
/// are rejected; missing required options use MissingOption in every scope.
/// Missing required positionals use MissingPositional. Integer syntax and
/// Int32 range are checked before returning an invocation.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[@cmder.int("count")])
///   assert_true(
///     app.parse(argv=["--count", "bad"])
///     is Failed(@cmder.CliError::InvalidInteger("count", "bad")),
///   )
/// }
/// ```
pub fn CliApp::parse(self : CliApp, argv~ : ArrayView[String]) -> ParseOutcome {
  let parser = build_parser(
    self.root,
    version=self.version,
    defer_required=true,
  )
  match parser.parse_outcome(argv=normalize_integer_argv(self.root, argv)) {
    Parsed(matches) =>
      Parsed(invocation_from_matches(self, matches)) catch {
        error => Failed(error)
      }
    Help(text) => Help(restore_parser_help(self, text, help_only=true))
    Version(text) => Version(text)
    Failed(error) => {
      let text = error.to_string()
      Failed(
        CliError::ParseError(restore_parser_help(self, text, help_only=false)),
      )
    }
  }
}

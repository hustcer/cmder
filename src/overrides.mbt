///|
/// Applies host overrides atomically and returns a fresh validated invocation.
/// Unknown names, incompatible kinds and invalid positional cardinality raise
/// CliError. Unchanged values preserve their sources; changed values use Override.
/// Clearing an optional positional makes it absent, with no effective source.
///
/// ```mbt check
/// test {
///   let app = @cmder.cli(name="app", options=[@cmder.int("count", default=1)])
///   guard app.parse(argv=[]) is Parsed(call) else { fail("parse") }
///   let edited = call.with_overrides({ "count": @cmder.ArgumentValue::Integer(3) })
///   assert_true(edited.context.get_int("count") == Some(3))
///   assert_true(call.context.get_int("count") == Some(1))
///   assert_true(edited.source_of("count") == Some(@cmder.ValueSource::Override))
/// }
/// ```
pub fn Invocation::with_overrides(
  self : Invocation,
  overrides : Map[String, ArgumentValue],
) -> Invocation raise CliError {
  let flags = self.context.flags.copy()
  let values = self.context.values.copy()
  let sources = self.context.sources.copy()
  for name, value in overrides {
    guard self.context.specs.get(name) is Some(spec) else {
      raise CliError::UnknownArgument(name)
    }
    match (spec, value) {
      (Option({ kind: BoolOpt, .. }), Flag(value)) => flags[name] = value
      (Option({ kind: StringOpt(_), .. }), Text(value)) =>
        values[name] = [value]
      (Option({ kind: IntOpt(_), .. }), Integer(value)) =>
        values[name] = [value.to_string()]
      (Option({ kind: IntOpt(_), .. }), Text(value)) => {
        ignore(parse_integer_value(name, value))
        values[name] = [value]
      }
      (Positional(pos, multiple~), Positionals(items)) => {
        if (pos.required && items.is_empty()) ||
          (!multiple && items.length() > 1) {
          raise CliError::InvalidOverride(
            name, "invalid number of positional values",
          )
        }
        if items.is_empty() {
          values.remove(name)
          sources.remove(name)
          continue
        }
        values[name] = items[:].to_owned()
      }
      _ =>
        raise CliError::InvalidOverride(
          name, "value does not match the argument kind",
        )
    }
    sources[name] = Override
  }
  { ..self, context: { ..self.context, flags, values, sources, }, }
}

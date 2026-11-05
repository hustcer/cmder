///|
test "string options retain typed defaults and normalized required metadata" {
  let required = @cmder.string(
    "name",
    short='n',
    description="User name",
    required=true,
  )
  assert_eq(required.name, "name")
  assert_true(required.short == Some('n'))
  assert_true(required.required)
  assert_false(required.global)
  assert_true(required.kind == @cmder.OptionKind::StringOpt(None))
  let defaulted = @cmder.string(
    "output",
    default="stdout",
    required=true,
    global=true,
  )
  assert_false(defaulted.required)
  assert_true(defaulted.global)
  assert_true(defaulted.short is None)
  assert_true(defaulted.kind == @cmder.OptionKind::StringOpt(Some("stdout")))
}

///|
test "integer options store integers instead of stringified defaults" {
  let required = @cmder.int("port", required=true)
  assert_true(required.required)
  assert_true(required.kind == @cmder.OptionKind::IntOpt(None))
  let defaulted = @cmder.int("count", short='c', default=3, required=true)
  assert_false(defaulted.required)
  assert_true(defaulted.kind == @cmder.OptionKind::IntOpt(Some(3)))
}

///|
test "boolean definitions have no required or default payload" {
  let option = @cmder.bool("quiet", short='q', global=true)
  assert_true(option.kind == @cmder.OptionKind::BoolOpt)
  assert_false(option.required)
  assert_true(option.global)
}

///|
test "integer getter accepts all Int32 boundaries and arbitrary padding" {
  for
    (text, expected) in [
      ("0", 0),
      ("-0", 0),
      ("42", 42),
      ("-42", -42),
      ("2147483647", 2147483647),
      ("-2147483648", -2147483648),
      ("0000000000000000000000000001", 1),
      ("-0000000000000000000000000042", -42),
    ] {
    let ctx = context_value("count", Some(text))
    assert_true(ctx.get_int("count") == Some(expected))
    assert_eq(ctx.get_int_required("count"), expected)
  }
}

///|
test "integer getter validates the complete spelling before overflow" {
  for
    text in [
      "", "-", "+1", "1.5", " 1", "1 ", "1e2", "abc", "--quiet", "999999999999999999x",
    ] {
    let ctx = context_value("count", Some(text))
    try ctx.get_int("count") catch {
      @cmder.CliError::InvalidInteger(name, raw) => {
        assert_eq(name, "count")
        assert_eq(raw, text)
      }
      error => raise error
    } noraise {
      _ => fail("expected invalid integer")
    }
  }
}

///|
test "integer overflow cannot wrap before range checking" {
  for
    text in [
      "2147483648", "-2147483649", "9999999999999999999999999999999999999",
    ] {
    try context_value("count", Some(text)).get_int("count") catch {
      @cmder.CliError::IntegerOutOfRange(name, raw) => {
        assert_eq(name, "count")
        assert_eq(raw, text)
      }
      error => raise error
    } noraise {
      _ => fail("expected overflow")
    }
  }
}

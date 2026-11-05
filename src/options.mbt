///|
/// Defines a string-valued option.
///
/// ```mbt check
/// test {
///   let option = @cmder.string("name", short='n', required=true)
///   assert_true(option.required)
/// }
/// ```
pub fn string(
  name : String,
  short? : Char,
  description~ : String = "",
  required~ : Bool = false,
  default? : String,
  global~ : Bool = false,
) -> OptionDef {
  {
    name,
    kind: StringOpt(default),
    short,
    description,
    required: match default {
      Some(_) => false
      None => required
    },
    global,
  }
}

///|
/// Defines a Boolean flag, which defaults to false.
///
/// ```mbt check
/// test {
///   let option = @cmder.bool("verbose", short='v')
///   inspect(option.name, content="verbose")
/// }
/// ```
pub fn bool(
  name : String,
  short? : Char,
  description~ : String = "",
  global~ : Bool = false,
) -> OptionDef {
  { name, kind: BoolOpt, short, description, required: false, global, }
}

///|
/// Defines an integer-valued option.
///
/// ```mbt check
/// test {
///   let option = @cmder.int("count", default=3)
///   inspect(option.required, content="false")
/// }
/// ```
pub fn int(
  name : String,
  short? : Char,
  description~ : String = "",
  required~ : Bool = false,
  default? : Int32,
  global~ : Bool = false,
) -> OptionDef {
  {
    name,
    kind: IntOpt(default),
    short,
    description,
    required: match default {
      Some(_) => false
      None => required
    },
    global,
  }
}

///|
fn option_default(opt : OptionDef) -> String? {
  match opt.kind {
    StringOpt(value) => value
    IntOpt(value) => value.map(v => v.to_string())
    BoolOpt => None
  }
}

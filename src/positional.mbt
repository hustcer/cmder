///|
/// Defines a local positional argument. The final positional accepts multiple
/// values; earlier positionals accept at most one. Declare required ones first.
/// Set multiple=false to limit even the final positional to one value.
///
/// ```mbt check
/// test {
///   let file = @cmder.positional("file", required=true, multiple=false)
///   assert_false(file.multiple)
/// }
/// ```
pub fn positional(
  name : String,
  description~ : String = "",
  required~ : Bool = false,
  multiple~ : Bool = true,
) -> PositionalDef {
  { name, description, required, multiple, }
}

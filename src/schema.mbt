///|
fn option_def_to_json(opt : OptionDef) -> Json {
  let m : Map[String, Json] = {
    "description": ToJson::to_json(opt.description),
    "required": ToJson::to_json(opt.required),
    "global": ToJson::to_json(opt.global),
  }
  match opt.kind {
    StringOpt(default) => {
      m["type"] = Json::string("string")
      if default is Some(value) {
        m["default"] = ToJson::to_json(value)
      }
    }
    IntOpt(default) => {
      m["type"] = Json::string("int")
      if default is Some(value) {
        m["default"] = ToJson::to_json(value)
      }
    }
    BoolOpt => {
      m["type"] = Json::string("bool")
      m["style"] = Json::string("flag")
    }
  }
  if opt.short is Some(short) {
    m["short"] = ToJson::to_json(short.to_string())
  }
  Json::object(m)
}

///|
fn positional_def_to_json(
  pos : PositionalDef,
  last : Bool,
  index : Int32,
) -> Json {
  Json::object({
    "description": ToJson::to_json(pos.description),
    "required": ToJson::to_json(pos.required),
    "index": ToJson::to_json(index),
    "min_args": ToJson::to_json(if pos.required { 1 } else { 0 }),
    "max_args": if last {
      Json::null()
    } else {
      ToJson::to_json(1)
    },
  })
}

///|
fn generate_example(path : String, cmd : CommandDef) -> String {
  let parts = [path]
  for opt in cmd.options {
    if opt.required {
      parts.push("--\{opt.name} <\{opt.name}>")
    }
  }
  for pos in cmd.positionals {
    if pos.required {
      parts.push("<\{pos.name}>")
    }
  }
  parts.join(" ")
}

///|
fn command_def_to_json(cmd : CommandDef, path : String) -> Json {
  let m : Map[String, Json] = {
    "description": ToJson::to_json(cmd.description),
  }
  if !cmd.options.is_empty() {
    let options : Map[String, Json] = Map([])
    for opt in cmd.options {
      options[opt.name] = option_def_to_json(opt)
    }
    m["options"] = Json::object(options)
  }
  if !cmd.positionals.is_empty() {
    let positionals : Map[String, Json] = Map([])
    for i, pos in cmd.positionals {
      positionals[pos.name] = positional_def_to_json(
        pos,
        i == cmd.positionals.length() - 1,
        i,
      )
    }
    m["positionals"] = Json::object(positionals)
  }
  if !cmd.examples.is_empty() {
    m["examples"] = ToJson::to_json(cmd.examples)
  } else if !cmd.options.is_empty() || !cmd.positionals.is_empty() {
    m["examples"] = ToJson::to_json([generate_example(path, cmd)])
  }
  if !cmd.subcommands.is_empty() {
    let commands : Map[String, Json] = Map([])
    for sub in cmd.subcommands {
      commands[sub.name] = command_def_to_json(
        sub,
        "\{generate_example(path, cmd)} \{sub.name}",
      )
    }
    m["commands"] = Json::object(commands)
  }
  Json::object(m)
}

///|
/// Exports normalized definitions with typed defaults, global metadata and root
/// positionals/examples. Only explicitly global options are inherited at runtime.
pub fn CliApp::render_schema_json(self : CliApp) -> Json {
  guard command_def_to_json(self.root, self.root.name) is Json::Object(fields) else {
    abort("object")
  }
  let m = fields.copy()
  m["name"] = ToJson::to_json(self.root.name)
  m["version"] = ToJson::to_json(self.version)
  Json::object(m)
}

///|
/// Returns the application schema as JSON text.
pub fn CliApp::render_schema(self : CliApp) -> String {
  self.render_schema_json().stringify()
}

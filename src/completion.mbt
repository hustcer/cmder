///|
fn collect_option_words(options : Array[CompletionOption]) -> String {
  let words : Array[String] = []
  for opt in options {
    if opt.long is Some(name) {
      words.push("--" + name)
    }
    if opt.short is Some(short) {
      words.push("-" + short.to_string())
    }
  }
  words.join(" ")
}

///|
fn collect_command_names(commands : Array[CompletionCommand]) -> String {
  commands.map(fn(c) { c.name }).join(" ")
}

///|
fn escape_single_quote(s : String) -> String {
  s.replace(old="'", new="'\\''")
}

///|
/// dollar sign as variable to avoid JS template literal collision
let dollar : String = "$"

// === Bash ===

///|
fn render_shell_scan(
  sb : StringBuilder,
  options : Array[CompletionOption],
  commands : Array[CompletionCommand],
  fn_name : String,
  limit : String,
) -> Unit {
  sb.write_string("  while (( pos < " + limit + " )); do\n")
  sb.write_string("    case \"" + dollar + "{words[pos]}\" in\n")
  sb.write_string("      --) return ;;\n")
  for opt in options {
    let patterns : Array[String] = []
    if opt.long is Some(name) {
      patterns.push("'--" + escape_single_quote(name) + "'")
    }
    if opt.short is Some(short) {
      patterns.push("'-" + escape_single_quote(short.to_string()) + "'")
    }
    let increment = if opt.takes_value { 2 } else { 1 }
    sb.write_string(
      "      " +
      patterns.join("|") +
      ") ((pos += " +
      increment.to_string() +
      ")) ;;\n",
    )
    if opt.takes_value && opt.long is Some(name) {
      sb.write_string(
        "      '--" + escape_single_quote(name) + "'=*) ((pos += 1)) ;;\n",
      )
    }
  }
  for i, cmd in commands {
    let sub_fn = fn_name + "_c" + i.to_string()
    sb.write_string(
      "      '" +
      escape_single_quote(cmd.name) +
      "') ((pos += 1)); " +
      sub_fn +
      "; return ;;\n",
    )
  }
  let has_short_options = options.any(opt => opt.short is Some(_))
  if has_short_options {
    sb.write_string("      -[!-]*)\n")
    sb.write_string(
      "        local rest=\"" + dollar + "{words[pos]#-}\" short\n",
    )
    sb.write_string("        ((pos += 1))\n")
    sb.write_string("        while [[ -n \"" + dollar + "rest\" ]]; do\n")
    sb.write_string(
      "          short=\"" +
      dollar +
      "{rest:0:1}\"; rest=\"" +
      dollar +
      "{rest:1}\"\n",
    )
    sb.write_string("          case \"" + dollar + "short\" in\n")
    for opt in options {
      if opt.short is Some(short) {
        let action = if !opt.takes_value {
          ":"
        } else {
          "[[ -z \"" + dollar + "rest\" ]] && ((pos += 1)); break"
        }
        sb.write_string(
          "            '" +
          escape_single_quote(short.to_string()) +
          "') " +
          action +
          " ;;\n",
        )
      }
    }
    sb.write_string(
      "            *) break ;;\n          esac\n        done ;;\n",
    )
  }
  sb.write_string("      *) ((pos += 1)) ;;\n")
  sb.write_string("    esac\n  done\n")
}

///|
fn render_bash_node(
  sb : StringBuilder,
  fn_name : String,
  options : Array[CompletionOption],
  commands : Array[CompletionCommand],
) -> Unit {
  sb.write_string(fn_name + "() {\n")
  render_shell_scan(sb, options, commands, fn_name, "cword")
  sb.write_string("  (( pos > cword )) && return\n")
  let candidates = collect_command_names(commands) +
    " " +
    collect_option_words(options)
  sb.write_string(
    "  COMPREPLY=($(compgen -W \"" +
    candidates +
    "\" -- \"" +
    dollar +
    "cur\"))\n",
  )
  sb.write_string("}\n\n")
  for i, cmd in commands {
    render_bash_node(
      sb,
      fn_name + "_c" + i.to_string(),
      cmd.options,
      cmd.subcommands,
    )
  }
}

///|
/// Generates a Bash completion script for this application.
///
/// ```mbt check
/// test {
///   assert_true(
///     @cmder.cli(name="demo").render_bash_completion().contains("complete -F"),
///   )
/// }
/// ```
pub fn CliApp::render_bash_completion(self : CliApp) -> String {
  let sb = StringBuilder()
  let fn_name = "_" + self.name.replace(old="-", new="_")
  sb.write_string(fn_name + "() {\n")
  sb.write_string("  COMPREPLY=()\n")
  // Bash splits words at COMP_WORDBREAKS (notably '=' and ':'). Rejoin
  // adjacent pieces using the original line, preserving actual whitespace.
  // Never eval command-line text: quotes and substitutions remain inert.
  sb.write_string(
    (
      #|  local -a words=()
      #|  local cword=0 i word gap
      #|  local line="${COMP_LINE:0:COMP_POINT}"
      #|  for ((i = 0; i <= COMP_CWORD; i++)); do
      #|    word="${COMP_WORDS[i]}"
      #|    if (( i == COMP_CWORD && $# >= 2 )); then
      #|      word="$2"
      #|    fi
      #|    if [[ -n "$word" ]]; then
      #|      gap="${line%%"$word"*}"
      #|      line="${line#*"$word"}"
      #|    else
      #|      gap="$line"
      #|    fi
      #|    if (( i == 0 )); then
      #|      words[0]="$word"
      #|    elif [[ -n "$gap" ]]; then
      #|      ((cword += 1))
      #|      words[cword]="$word"
      #|    else
      #|      words[cword]+="$word"
      #|    fi
      #|  done
      #|
    ),
  )
  sb.write_string("  local cur=\"" + dollar + "{words[cword]}\"\n")
  sb.write_string("  local pos=1\n")
  sb.write_string("  " + fn_name + "_root\n")
  sb.write_string("}\n\n")
  render_bash_node(
    sb,
    fn_name + "_root",
    completion_options(self.root_options, version=true),
    completion_commands(self.commands, self.root_options),
  )
  sb.write_string("complete -F " + fn_name + " " + self.name + "\n")
  sb.to_string()
}

// === Zsh ===

///|
fn render_zsh_options(
  sb : StringBuilder,
  options : Array[CompletionOption],
) -> Unit {
  if options.length() == 0 {
    return
  }
  sb.write_string("  _arguments \\\n")
  for i, opt in options {
    let desc = escape_single_quote(opt.description)
    let value_spec = if opt.takes_value { ":value:" } else { "" }
    let spellings : Array[String] = []
    if opt.short is Some(short) {
      spellings.push("'-\{short}[\{desc}]\{value_spec}'")
    }
    if opt.long is Some(name) {
      spellings.push("'--\{name}[\{desc}]\{value_spec}'")
    }
    let flag = spellings.join(" ")
    let end = if i < options.length() - 1 { " \\" } else { "" }
    sb.write_string("    " + flag + end + "\n")
  }
}

///|
fn render_zsh_command(
  sb : StringBuilder,
  cmd : CompletionCommand,
  fn_name : String,
) -> Unit {
  sb.write_string(fn_name + "() {\n")
  sb.write_string("  local start=" + dollar + "((pos - 1))\n")
  render_shell_scan(sb, cmd.options, cmd.subcommands, fn_name, "CURRENT")
  sb.write_string("  (( pos > CURRENT )) && return\n")
  if cmd.subcommands.length() > 0 {
    sb.write_string("  local -a commands\n")
    sb.write_string("  commands=(\n")
    for sub in cmd.subcommands {
      let desc = escape_single_quote(sub.description)
      sb.write_string("    '" + sub.name + ":" + desc + "'\n")
    }
    sb.write_string("  )\n")
    sb.write_string("  _describe 'command' commands\n")
  }
  if cmd.options.length() > 0 {
    sb.write_string(
      "  local -a words=(\"" +
      dollar +
      "{words[@]:" +
      dollar +
      "((start - 1))}\")\n",
    )
    sb.write_string("  local CURRENT=" + dollar + "((CURRENT - start + 1))\n")
    render_zsh_options(sb, cmd.options)
  }
  sb.write_string("}\n\n")
  for i, sub in cmd.subcommands {
    render_zsh_command(sb, sub, fn_name + "_c" + i.to_string())
  }
}

///|
/// Generates a Zsh completion script for this application.
///
/// ```mbt check
/// test {
///   assert_true(
///     @cmder.cli(name="demo").render_zsh_completion().contains("#compdef demo"),
///   )
/// }
/// ```
pub fn CliApp::render_zsh_completion(self : CliApp) -> String {
  let sb = StringBuilder()
  sb.write_string("#compdef " + self.name + "\n\n")
  let fn_name = "_" + self.name.replace(old="-", new="_")
  sb.write_string(fn_name + "() {\n")
  sb.write_string("  local pos=2\n")
  let root_options = completion_options(self.root_options, version=true)
  let commands = completion_commands(self.commands, self.root_options)
  render_shell_scan(sb, root_options, commands, fn_name, "CURRENT")
  sb.write_string("  (( pos > CURRENT )) && return\n")
  sb.write_string("  local -a commands\n")
  sb.write_string("  commands=(\n")
  for cmd in commands {
    let desc = escape_single_quote(cmd.description)
    sb.write_string("    '" + cmd.name + ":" + desc + "'\n")
  }
  sb.write_string("  )\n")
  sb.write_string("  _describe 'command' commands\n")
  render_zsh_options(sb, root_options)
  sb.write_string("}\n\n")
  for i, cmd in commands {
    render_zsh_command(sb, cmd, fn_name + "_c" + i.to_string())
  }
  sb.write_string("compdef " + fn_name + " " + self.name + "\n")
  sb.to_string()
}

// === Fish ===

///|
fn render_fish_options(
  sb : StringBuilder,
  app_name : String,
  condition : String,
  options : Array[CompletionOption],
) -> Unit {
  for opt in options {
    let mut line = "complete -c " + app_name + " " + condition + " "
    if opt.long is Some(name) {
      line = line + " -l " + name
    }
    if opt.short is Some(short) {
      line = line + " -s " + short.to_string()
    }
    if opt.description.length() > 0 {
      line = line + " -d '" + escape_single_quote(opt.description) + "'"
    }
    if opt.takes_value {
      line = line + " -r"
    }
    sb.write_string(line + "\n")
  }
}

///|
// Emit one state per command path. Option values must not select subcommands.
fn render_fish_states(
  sb : StringBuilder,
  state : String,
  options : Array[CompletionOption],
  commands : Array[CompletionCommand],
) -> Unit {
  sb.write_string("      case " + state + "\n        switch \"$word\"\n")
  for opt in options {
    sb.write_string("          case")
    if opt.long is Some(name) {
      sb.write_string(" '--" + escape_single_quote(name) + "'")
    }
    if opt.short is Some(short) {
      sb.write_string(" '-" + escape_single_quote(short.to_string()) + "'")
    }
    sb.write_string("\n")
    if opt.takes_value {
      sb.write_string("            set skip 1\n")
      if opt.long is Some(name) {
        sb.write_string(
          "          case '--" + escape_single_quote(name) + "=*'\n",
        )
      }
    }
  }
  for i, cmd in commands {
    sb.write_string("          case '" + escape_single_quote(cmd.name) + "'\n")
    sb.write_string(
      "            set state " + state + "_c" + i.to_string() + "\n",
    )
  }
  if options.any(opt => opt.short is Some(_)) {
    sb.write_string(
      (
        #|          case '-*'
        #|            set -l rest (string sub -s 2 -- "$word")
        #|            while test -n "$rest"
        #|              set -l short (string sub -l 1 -- "$rest")
        #|              set rest (string sub -s 2 -- "$rest")
        #|              switch "$short"
        #|
      ),
    )
    for opt in options {
      if opt.short is Some(short) {
        sb.write_string(
          "                case '" +
          escape_single_quote(short.to_string()) +
          "'\n",
        )
        if opt.takes_value {
          sb.write_string(
            (
              #|                  if test -z "$rest"
              #|                    set skip 1
              #|                  end
              #|                  break
              #|
            ),
          )
        }
      }
    }
    sb.write_string(
      "                case '*'\n                  break\n              end\n            end\n",
    )
  }
  sb.write_string("        end\n")
  for i, cmd in commands {
    render_fish_states(
      sb,
      state + "_c" + i.to_string(),
      cmd.options,
      cmd.subcommands,
    )
  }
}

///|
fn render_fish_node(
  sb : StringBuilder,
  app_name : String,
  context_fn : String,
  state : String,
  options : Array[CompletionOption],
  commands : Array[CompletionCommand],
) -> Unit {
  let condition = "-n '" + context_fn + " " + state + "'"
  render_fish_options(sb, app_name, condition, options)
  for i, cmd in commands {
    let desc = escape_single_quote(cmd.description)
    let line = "complete -c " +
      app_name +
      " " +
      condition +
      " -a " +
      "'" +
      escape_single_quote(cmd.name) +
      "'" +
      " -d '" +
      desc +
      "'"
    sb.write_string(line + "\n")
    render_fish_node(
      sb,
      app_name,
      context_fn,
      state + "_c" + i.to_string(),
      cmd.options,
      cmd.subcommands,
    )
  }
}

///|
/// Generates a Fish completion script for this application.
///
/// ```mbt check
/// test {
///   assert_true(
///     @cmder.cli(name="demo")
///     .render_fish_completion()
///     .contains("Fish completions"),
///   )
/// }
/// ```
pub fn CliApp::render_fish_completion(self : CliApp) -> String {
  let sb = StringBuilder()
  sb.write_string("# Fish completions for " + self.name + "\n")
  let context_fn = "__" + self.name.replace(old="-", new="_") + "_context"
  sb.write_string("function " + context_fn + "\n")
  sb.write_string(
    (
      #|  set -l words (commandline -opc)
      #|  set -l state root
      #|  set -l skip 0
      #|  for word in $words[2..-1]
      #|    if test $skip -eq 1
      #|      set skip 0
      #|      continue
      #|    end
      #|    if test "$word" = --
      #|      return 1
      #|    end
      #|    switch $state
      #|
    ),
  )
  let root_options = completion_options(self.root_options, version=true)
  let commands = completion_commands(self.commands, self.root_options)
  render_fish_states(sb, "root", root_options, commands)
  sb.write_string(
    (
      #|    end
      #|  end
      #|  test $skip -eq 0; and test "$state" = "$argv[1]"
      #|end
      #|
    ),
  )
  render_fish_node(sb, self.name, context_fn, "root", root_options, commands)
  sb.to_string()
}

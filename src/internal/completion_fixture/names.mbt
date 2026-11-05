///|
fn name_completions(shell : String) -> String raise {
  let sb = StringBuilder()
  for i, name in ["tool.exe", "中文工具", "foo-bar", "foo_bar", "tool+"] {
    let app = @cmder.cli(name~, commands=[
      @cmder.command(name="发布.v2+", options=[@cmder.bool("ready\{i}")]),
    ])
    sb.write_string(
      match shell {
        "bash-names" => app.render_bash_completion()
        "zsh-names" => app.render_zsh_completion()
        "fish-names" => app.render_fish_completion()
        _ => abort("unknown shell")
      },
    )
    sb.write_string("\n")
  }
  sb.to_string()
}

#!/usr/bin/env nu
# Requires Nushell 0.116+, MoonBit, Bash, Fish, and Zsh.
def checked [program: string, args: list<string>]: nothing -> string {
  let result = (run-external $program ...$args | complete)
  if $result.exit_code != 0 {
    error make {msg: $'($program) failed: ($result.stderr)($result.stdout)'}
  }
  $result.stdout
}

def main [] {
  let repo = ($env.CURRENT_FILE | path dirname | path dirname)
  cd $repo
  let scratch = (mktemp --directory)
  try {
    let fixtures = ($scratch | path join fixtures)
    mkdir ($fixtures | path join documents)
    '' | save ($fixtures | path join documents 'quarter report.pptx')
    '' | save ($fixtures | path join '--literal.pptx')
    let inputrc = ($scratch | path join inputrc)
    '' | save $inputrc
    # Reproduce compinit's permission prompt without changing system directories.
    let insecure_fpath = ($scratch | path join insecure-zfuncs)
    mkdir $insecure_fpath
    checked chmod [o+w $insecure_fpath] | ignore
    for shell in [bash fish zsh] {
      let generated = (checked moon [run src/internal/completion_fixture --target native -- $shell])
      let completion_file = ($scratch | path join $'completion.($shell)')
      $generated | save $completion_file
      let names = (checked moon [run src/internal/completion_fixture --target native -- $'($shell)-names'])
      let names_file = ($scratch | path join $'names.($shell)')
      $names | save $names_file
      let test_file = ($repo | path join scripts shell-tests $'completion.($shell)')
      with-env {CMDER_COMPLETION_FILE: $completion_file, CMDER_NAMES_FILE: $names_file} {
        let args = match $shell {
          bash => [--noprofile --norc $test_file]
          fish => [--no-config $test_file]
          zsh => [-f $test_file]
        }
        print (checked $shell $args | str trim)
      }
    }
    with-env {
      CMDER_COMPLETION_ROOT: $scratch
      CMDER_COMPLETION_FIXTURES: $fixtures
      CMDER_CAPTURE_FILE: ($scratch | path join captured-buffer.txt)
      CMDER_INSECURE_FPATH: $insecure_fpath
      INPUTRC: $inputrc
    } {
      print (checked zsh [-f ($repo | path join scripts shell-tests completion-interactive.zsh)] | str trim)
    }
  } finally {
    # Only this invocation's mktemp directory is removed.
    rm --recursive $scratch
  }
}

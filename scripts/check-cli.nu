#!/usr/bin/env nu
# Check the process boundary on each supported backend. Only the fixture decides
# to print and exit; cmder's parse API must return every outcome to its host.
def run-fixture [target: string, args: list<string>]: nothing -> string {
  let result = (^moon run src/internal/completion_fixture --target $target -- ...$args | complete)
  if $result.exit_code != 0 {
    error make {msg: $'CLI fixture failed on ($target): ($result.stderr)($result.stdout)'}
  }
  $result.stdout | str trim
}

def main [] {
  cd ($env.CURRENT_FILE | path dirname | path dirname)
  for target in [js native wasm-gc] {
    let executed = (run-fixture $target [files a.txt b.txt])
    if $executed != "callback files: a.txt,b.txt\nreturned from run" {
      error make {msg: $'Process argv handling failed on ($target): ($executed)'}
    }
    let version = (run-fixture $target [--version])
    if $version != '1.2.3' {
      error make {msg: $'run did not print and exit for version on ($target): ($version)'}
    }
    let help = (run-fixture $target [files --help])
    if not ($help | str contains 'Usage: cmder-test files') or not ($help | str contains 'Examples:') or ($help | str contains 'returned from run') {
      error make {msg: $'run help behavior failed on ($target): ($help)'}
    }
    for case in [
      {args: [parse-help], expected: 'Usage: cmder-test files'}
      {args: [parse-version], expected: '1.2.3'}
      {args: [parse-error], expected: '--unknown'}
    ] {
      let text = (run-fixture $target $case.args)
      if not ($text | str contains $case.expected) or not ($text | str ends-with 'returned to host') or ($text | str contains 'callback files:') {
        error make {msg: $'parse performed unexpected effects on ($target): ($text)'}
      }
    }
    print $'CLI ($target): 6 process checks passed'
  }
}

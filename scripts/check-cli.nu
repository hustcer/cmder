#!/usr/bin/env nu
# Check the process boundary on each supported backend. The application owns
# error reporting and exit status; parse must return every outcome to its host.
def run-fixture [target: string, args: list<string>]: nothing -> string {
  let result = (^moon run src/internal/completion_fixture --target $target -- ...$args | complete)
  if $result.exit_code != 0 {
    error make {msg: $'CLI fixture failed on ($target): ($result.stderr)($result.stdout)'}
  }
  $result.stdout | str trim
}

def check-example [target: string]: nothing -> nothing {
  let successes = [
    {args: [greet --name Ada], expected: 'Hello, Ada!'}
    {args: [greet --name Ada --count '2'], expected: "Hello, Ada!\nHello, Ada!"}
    {args: [db migrate up --steps '2'], expected: "Applying 2 migrations...\nDone."}
    {args: [--version], expected: '0.1.0'}
  ]
  for case in $successes {
    let result = (^moon run src/examples/cli --target $target -- ...$case.args | complete)
    if $result.exit_code != 0 or ($result.stdout | str trim) != $case.expected or ($result.stderr | is-not-empty) {
      error make {msg: $'Example success handling failed on ($target): ($result)'}
    }
  }
  let help = (^moon run src/examples/cli --target $target -- greet --help | complete)
  if $help.exit_code != 0 or not ($help.stdout | str contains 'Usage: myapp greet') or ($help.stderr | is-not-empty) {
    error make {msg: $'Example help handling failed on ($target): ($help)'}
  }
  let failures = [
    {args: [greet --name Ada --count bad], expected: "invalid integer for 'count': 'bad'"}
    {args: [greet --name Ada --count '2147483648'], expected: "integer out of Int32 range for 'count': '2147483648'"}
    {args: [db migrate up --steps bad], expected: "invalid integer for 'steps': 'bad'"}
    {args: [greet], expected: 'missing required option: name'}
    {args: [db], expected: "missing subcommand for 'db'"}
  ]
  for case in $failures {
    let result = (^moon run src/examples/cli --target $target -- ...$case.args | complete)
    if $result.exit_code != 1 {
      error make {msg: $'Example did not report failure on ($target): ($result)'}
    }
    # MoonBit's eprintln currently falls back to stdout on wasm-gc.
    let diagnostic = if $target == 'wasm-gc' { $result.stdout } else { $result.stderr }
    if not ($diagnostic | str contains $case.expected) or ($target != 'wasm-gc' and ($result.stdout | is-not-empty)) {
      error make {msg: $'Example diagnostic handling failed on ($target): ($result)'}
    }
  }
  let count = ($successes | length) + ($failures | length) + 1
  print $'Example ($target): ($count) process checks passed'
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
    let parse_cases = [
      {args: [parse-help], expected: 'Usage: cmder-test files'}
      {args: [parse-version], expected: '1.2.3'}
      {args: [parse-error], expected: '--unknown'}
    ]
    for case in $parse_cases {
      let text = (run-fixture $target $case.args)
      if not ($text | str contains $case.expected) or not ($text | str ends-with 'returned to host') or ($text | str contains 'callback files:') {
        error make {msg: $'parse performed unexpected effects on ($target): ($text)'}
      }
    }
    let executions = [
      {args: [input.txt other.txt], expected: "callback root: input.txt,other.txt\nreturned from run"}
      {args: [--trace files a.txt], expected: "trace enabled\ncallback files: a.txt\nreturned from run"}
      {args: [files --trace a.txt], expected: "trace enabled\ncallback files: a.txt\nreturned from run"}
    ]
    for case in $executions {
      let output = (run-fixture $target $case.args)
      if $output != $case.expected {
        error make {msg: $'Root/global execution failed on ($target): ($output)'}
      }
    }
    let rejections = [reject exit-reject]
    for argument in $rejections {
      let failed = (^moon run src/internal/completion_fixture --target $target -- $argument | complete)
      let diagnostic = if $target == 'wasm-gc' { $failed.stdout } else { $failed.stderr }
      if $failed.exit_code != 1 or not ($diagnostic | str contains 'Rejected') or ($failed.stdout | str contains 'returned from run') or ($failed.stdout | str contains 'unexpected return') {
        error make {msg: $'Original callback error was not reported on ($target): ($failed)'}
      }
    }
    let count = ($parse_cases | length) + ($executions | length) + ($rejections | length) + 3
    print $'CLI ($target): ($count) process checks passed'
    check-example $target
  }
}

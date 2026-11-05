#!/usr/bin/env nu
# Nushell 0.116+. Compile the actual README snippets against this worktree,
# then run them on every supported backend. No published cmder dependency.
use std/assert

def fences [text: string]: nothing -> table<language: string, code: string> {
  $text | parse --regex r#'(?ms)^```(?P<language>[^\n]*)\n(?P<code>.*?)^```\s*$'#
}

def examples [text: string]: nothing -> list<record> {
  let snippets = ($text | parse --regex r#'(?ms)^<!-- cmder-example (?P<meta>[^\n]+) -->\n\n```moonbit\n(?P<code>.*?)^```\s*$'#)
  assert equal ($snippets | length) (fences $text | where language == moonbit | length) 'Every MoonBit block needs a cmder-example marker'
  let markers = ($text | lines | where {|line| $line | str starts-with '<!-- cmder-example ' } | length)
  assert equal ($snippets | length) $markers 'Every cmder-example marker must precede a MoonBit block'
  assert ($snippets | is-not-empty) 'No README examples found'
  let parsed = ($snippets | each {|snippet|
    let meta = ($snippet.meta | from json)
    assert ($meta.id =~ r#'^[a-z][a-z0-9-]*$'#) 'Invalid example id'
    assert ($meta.kind in [program pure raising]) 'Unknown example kind'
    {meta: $meta, code: $snippet.code}
  })
  assert equal ($parsed | get meta.id | uniq | length) ($parsed | length) 'Duplicate example id'
  $parsed
}

# Contexts refer to other README snippets by id, never by block position.
def fragment [example: record, all: list<record>, seen: list<string> = []]: nothing -> string {
  assert ($example.meta.id not-in $seen) 'Cyclic README example context'
  let context = if ($example.meta.context? | is-not-empty) {
    let matches = ($all | where meta.id == $example.meta.context)
    assert equal ($matches | length) 1 'Unknown README example context'
    let parent = ($matches | first)
    assert ($parent.meta.kind != program) 'Programs cannot be fragment contexts'
    fragment $parent $all ($seen | append $example.meta.id)
  } else { '' }
  let ignored = ($example.meta.binds? | default [] | each {|name|
    assert ($name =~ r#'^[a-z][a-z0-9_]*$'#) 'Invalid README binding'
    ['ignore(' $name ')'] | str join
  } | str join "\n")
  [$context $example.code $ignored] | str join "\n"
}

def checked [args: list<string>]: nothing -> string {
  let result = (^moon ...$args | complete)
  assert equal $result.exit_code 0 $'moon ($args | str join " ") failed: ($result.stderr)($result.stdout)'
  $result.stdout
}

# Check bilingual code/metadata parity; compile and execute all marked snippets.
def main [] {
  cd ($env.CURRENT_FILE | path dirname | path dirname)
  let english = (open --raw README.md | str replace --all "\r\n" "\n")
  let chinese = (open --raw README.zh.md | str replace --all "\r\n" "\n")
  assert ((fences $english) == (fences $chinese)) 'README code blocks differ between languages'
  let snippets = (examples $english)
  assert ($snippets == (examples $chinese)) 'README example metadata differs between languages'
  let scratch = (mktemp --directory --tmpdir-path ($env.PWD | path join src internal) readme_check_XXXXXXXX)
  try {
    for example in $snippets {
      let package = ($scratch | path join $example.meta.id)
      mkdir $package
      let source = if $example.meta.kind == program { $example.code } else {
        let header = if $example.meta.kind == pure { "///|\nfn main {\n" } else { "///|\nfn main raise {\n" }
        [$header (fragment $example $snippets) "\n}\n"] | str join
      }
      # Import env only for snippets that use it, so deny-warn covers imports.
      let imports = if ($source | str contains '@env.') {
        'import { "hustcer/cmder", "moonbitlang/core/env" }'
      } else { 'import { "hustcer/cmder" }' }
      # A package inside the current module resolves hustcer/cmder to src/.
      [$imports "\npkgtype(kind: \"executable\")\n"] | str join | save ($package | path join moon.pkg)
      $source | save ($package | path join main.mbt)
      # moon check on the parent directory does not recursively check packages.
      checked [check --deny-warn --target all $package] | ignore
    }
    for target in [native js wasm-gc] {
      for example in $snippets {
        let package = ($scratch | path join $example.meta.id)
        let args = ($example.meta.args? | default [])
        let output = (checked ([run $package --target $target --] | append $args))
        assert equal $output ($example.meta.stdout? | default '') $'Unexpected output: ($example.meta.id) / ($target)'
        if ($example.meta.fail_args? | is-not-empty) {
          let result = (^moon run $package --target $target -- ...$example.meta.fail_args | complete)
          assert equal $result.exit_code 1 $'Error exit status: ($example.meta.id) / ($target)'
          let diagnostic = if $target == wasm-gc { $result.stdout } else { $result.stderr }
          assert str contains $diagnostic $example.meta.error
          if $target != wasm-gc { assert equal $result.stdout '' }
        }
      }
      print $'README ($target): ($snippets | length) examples compiled and executed'
    }
    print $'README: (fences $english | length) bilingual code blocks and example metadata match'
  } finally {
    # Only this invocation's randomly created source packages are removed.
    rm --recursive $scratch
  }
}

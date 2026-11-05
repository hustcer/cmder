# Capture calls to the completion widgets outside an interactive ZLE session.
# The generated scanner and dispatcher execute in real Zsh.
typeset -A registered_completions
compdef() { completion_function=$1; registered_completions[$2]=$1; }
_describe() { described=("${commands[@]}"); }
_arguments() { specs=("$@"); }
source "$CMDER_COMPLETION_FILE"
checks=0
check() {
  local expected=$1
  shift
  words=(cmder-test "$@")
  CURRENT=${#words[@]}
  specs=()
  described=()
  "$completion_function"
  local actual="${(j: :)specs}"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Zsh: %s: expected <%s>, got <%s>\n' "$*" "$expected" "$actual" >&2
    exit 1
  fi
  ((checks += 1))
}
help_specs='-h[Show help information.] --help[Show help information.]'
db_specs="--trace[] --db-only[] -f[]:value: --format[]:value: $help_specs"
check "$db_specs" db inspect --
check "--trace[] --cache-only[] $help_specs" cache inspect --
check "$db_specs" --profile cache db inspect --
check "$db_specs" -vp cache db inspect --
check "$db_specs" -vpcache db inspect --
check '' db inspect --format ''
check '' files -- --f
check '' -- db inspect --db
check '' db -- inspect --db
check "-v[] --verbose[] -p[]:value: --profile[]:value: --trace[] $help_specs -V[Show version information.] --version[Show version information.]" --
check "--trace[] --force[] $help_specs" files --
check "$help_specs" help db inspect --
check '--trace[] --help[]:value: -h[Show help information.]' custom-help --
check '--trace[] -h[]:value: --host[]:value: --help[Show help information.]' custom-short --
check '' custom-help --help ''
check '' custom-short -h ''
check "$db_specs" --trace db inspect --
check "$db_specs" db --trace inspect --
words=(cmder-test help db '')
CURRENT=${#words[@]}
specs=()
described=()
"$completion_function"
if [[ "${(j: :)described}" != 'inspect:' ]]; then
  print -u2 -- 'Zsh: help topics did not follow the command hierarchy'
  exit 1
fi
((checks += 1))
# Check the actual shell-decoded _arguments field, including its inner grammar.
expected_value=$(cat <<'SPEC'
--value[\\';echo cmder-description;# \[x\]\: \[y\]\: 'again' \\]:value:
SPEC
)
words=(cmder-test quoting --)
CURRENT=${#words[@]}
specs=()
"$completion_function"
if [[ "${specs[2]}" != "$expected_value" ]]; then
  print -u2 -- 'Zsh: option description was not encoded for _arguments'
  exit 1
fi
((checks += 1))
root_specs="-v[] --verbose[] -p[]:value: --profile[]:value: --trace[] $help_specs -V[Show version information.] --version[Show version information.]"
check "$root_specs" input.txt files --
if (( ${#described} != 0 )); then
  print -u2 -- 'Zsh: positional input must suppress subcommand suggestions'
  exit 1
fi
source "$CMDER_NAMES_FILE"
index=0
for app_name in tool.exe 中文工具 foo-bar foo_bar tool+; do
  completion_function=${registered_completions[$app_name]}
  check "--ready${index}[] $help_specs" 发布.v2+ --
  words=("$app_name" 发)
  CURRENT=${#words[@]}
  described=()
  "$completion_function"
  if [[ "${described[1]}" != '发布.v2+:' ]]; then
    print -u2 -- 'Zsh: Unicode command suggestion lost'
    exit 1
  fi
  ((checks += 1))
  ((index += 1))
done
printf 'Zsh: %s dispatch checks passed\n' "$checks"

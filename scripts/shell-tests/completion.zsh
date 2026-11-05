# Capture calls to the completion widgets outside an interactive ZLE session.
# The generated scanner and dispatcher execute in real Zsh.
typeset -A registered_completions
compdef() { completion_function=$1; registered_completions[$2]=$1; }
_describe() { described=("${commands[@]}"); }
_arguments() { specs=("$@"); }
_files() { file_requests=$((file_requests + 1)); }
source "$CMDER_COMPLETION_FILE"
checks=0
check() {
  local expected=$1
  shift
  words=(cmder-test "$@")
  CURRENT=${#words[@]}
  specs=()
  described=()
  file_requests=0
  "$completion_function"
  local actual="${(j: :)specs}"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Zsh: %s: expected <%s>, got <%s>\n' "$*" "$expected" "$actual" >&2
    exit 1
  fi
  ((checks += 1))
}
path_spec='*:path:_files'
help_options='-h[Show help information.] --help[Show help information.]'
help_specs="$help_options $path_spec"
db_specs="--trace[] --db-only[] -f+[]:value:_files --format=[]:value:_files $help_specs"
check "$db_specs" db inspect --
check "--trace[] --cache-only[] $help_specs" cache inspect --
check "$db_specs" --profile cache db inspect --
check "$db_specs" -vp cache db inspect --
check "$db_specs" -vpcache db inspect --
check '' db inspect --format ''
check '' files -- --f
check '' -- db inspect --db
check '' db -- inspect --db
check "-v[] --verbose[] -p+[]:value:_files --profile=[]:value:_files --trace[] $help_options -V[Show version information.] --version[Show version information.] $path_spec" --
check "--trace[] --force[] $help_specs" files --
check "$help_specs" help db inspect --
check "--trace[] --help=[]:value:_files -h[Show help information.] $path_spec" custom-help --
check "--trace[] -h+[]:value:_files --host=[]:value:_files --help[Show help information.] $path_spec" custom-short --
check '' custom-help --help ''
check '' custom-short -h ''
for route in 'db inspect --format' 'files --' 'custom-short -h'; do
  check '' ${(z)route} ''
  if (( file_requests != 1 )); then
    print -u2 -- "Zsh: expected filename fallback after $route"
    exit 1
  fi
  ((checks += 1))
done
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
--value=[\\';echo cmder-description;# \[x\]\: \[y\]\: 'again' \\]:value:_files
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
root_specs="-v[] --verbose[] -p+[]:value:_files --profile=[]:value:_files --trace[] $help_options -V[Show version information.] --version[Show version information.] $path_spec"
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

# Capture calls to the completion widgets outside an interactive ZLE session.
# The generated scanner and dispatcher execute in real Zsh.
compdef() { :; }
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
  _cmder_test
  local actual="${(j: :)specs}"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Zsh: %s: expected <%s>, got <%s>\n' "$*" "$expected" "$actual" >&2
    exit 1
  fi
  ((checks += 1))
}
help_specs='-h[Show help information.] --help[Show help information.]'
db_specs="--db-only[] -f[]:value: --format[]:value: $help_specs"
check "$db_specs" db inspect --
check "--cache-only[] $help_specs" cache inspect --
check "$db_specs" --profile cache db inspect --
check "$db_specs" -vp cache db inspect --
check "$db_specs" -vpcache db inspect --
check '' db inspect --format ''
check '' files -- --f
check '' -- db inspect --db
check '' db -- inspect --db
check "-v[] --verbose[] -p[]:value: --profile[]:value: $help_specs -V[Show version information.] --version[Show version information.]" --
check "--force[] $help_specs" files --
check "$help_specs" help db inspect --
check '--help[]:value: -h[Show help information.]' custom-help --
check '-h[]:value: --host[]:value: --help[Show help information.]' custom-short --
check '' custom-help --help ''
check '' custom-short -h ''
words=(cmder-test help db '')
CURRENT=${#words[@]}
specs=()
described=()
_cmder_test
if [[ "${(j: :)described}" != 'inspect:' ]]; then
  print -u2 -- 'Zsh: help topics did not follow the command hierarchy'
  exit 1
fi
((checks += 1))
printf 'Zsh: %s dispatch checks passed\n' "$checks"

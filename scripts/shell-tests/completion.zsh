# Capture calls to the completion widgets outside an interactive ZLE session.
# The generated scanner and dispatcher execute in real Zsh.
compdef() { :; }
_describe() { :; }
_arguments() { specs=("$@"); }
source "$CMDER_COMPLETION_FILE"
checks=0
check() {
  local expected=$1
  shift
  words=(cmder-test "$@")
  CURRENT=${#words[@]}
  specs=()
  _cmder_test
  local actual="${(j: :)specs}"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Zsh: %s: expected <%s>, got <%s>\n' "$*" "$expected" "$actual" >&2
    exit 1
  fi
  ((checks += 1))
}
db_specs='--db-only[] -f[]:value: --format[]:value:'
check "$db_specs" db inspect --
check '--cache-only[]' cache inspect --
check "$db_specs" --profile cache db inspect --
check "$db_specs" -vp cache db inspect --
check "$db_specs" -vpcache db inspect --
check '' db inspect --format ''
check '' files -- --f
check '' -- db inspect --db
check '' db -- inspect --db
printf 'Zsh: %s dispatch checks passed\n' "$checks"

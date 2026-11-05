# Bash code is the test subject; orchestration lives in check-completions.nu.
source "$CMDER_COMPLETION_FILE"
read -r _ _ completion_function _ <<< "$(complete -p cmder-test)"
checks=0
check() {
  local expected=$1
  shift
  COMP_WORDS=(cmder-test "$@")
  COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
  COMP_LINE=${test_line:-"${COMP_WORDS[*]}"}
  COMP_POINT=${cursor_point:-${#COMP_LINE}}
  COMPREPLY=(stale)
  "$completion_function" cmder-test "${cursor_word-${COMP_WORDS[COMP_CWORD]}}"
  local actual="${COMPREPLY[*]}"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Bash: %s: expected <%s>, got <%s>\n' "$*" "$expected" "$actual" >&2
    exit 1
  fi
  checks=$((checks + 1))
}
check '--verbose --version' --v
check '--profile' --p
check '--db-only' db inspect --db
cursor_word=--db cursor_point=26 test_line='cmder-test db inspect --dbZ' check '--db-only' db inspect --dbZ
check '--cache-only' cache inspect --cache
check '' db inspect --cache
check '' cache inspect --db
check '--db-only' --profile cache db inspect --db
check '--db-only' --profile=cache db inspect --db
test_line='cmder-test --profile=cache db inspect --db' check '--db-only' --profile = cache db inspect --db
test_line='cmder-test --profile=cache ' check 'db cache files custom-help custom-short quoting help --verbose -v --profile -p --trace --help -h --version -V' --profile = cache ''
test_line='cmder-test --profile=cache:db db inspect --db' check '--db-only' --profile = cache : db db inspect --db
check '--db-only' --profile = db inspect --db
check '--db-only' --profile "'cache db'" db inspect --db
check '--db-only' -vp cache db inspect --db
check '--db-only' -vpcache db inspect --db
check '--db-only' db --region cache inspect --db
check '' --profile ''
check '' db inspect --format ''
check '' files -- --f
check '' -- db inspect --db
check '' db -- inspect --db
check '--help' --h
check '--version' --version
check '-V' -V
check 'help' he
check '--help' db inspect --h
check '' db inspect --version
check 'db' help d
check 'inspect' help db i
check '--help' help db inspect --h
check '' help db inspect --db
check 'inspect' db help i
check '' custom-help --help ''
check '-h' custom-help -h
check '--help' custom-short --hel
check '' custom-short -h ''
check '--trace' --tr
check '--trace' db inspect --tr
check '--trace' files --tr
check '--db-only' --trace db inspect --db
check '--value' quoting --val
check '' input.txt fi
check '' input.txt files --f
check '--trace' input.txt --tr
source "$CMDER_NAMES_FILE"
index=0
for app_name in tool.exe 中文工具 foo-bar foo_bar tool+; do
  read -r _ _ completion_function _ <<< "$(complete -p "$app_name")"
  check "--ready$index" 发布.v2+ --rea
  check '发布.v2+' 发
  index=$((index + 1))
done
printf 'Bash: %s behavior checks passed\n' "$checks"

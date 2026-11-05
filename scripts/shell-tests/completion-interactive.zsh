# Drive actual Readline/ZLE Tab completion. Test orchestration and fixture
# ownership live in check-completions.nu; zpty provides the required terminal.
zmodload zsh/zpty || exit 1
zmodload zsh/zselect || exit 1
checks=0

wait_for_buffer() {
  local deadline=$((SECONDS + 10)) output transcript=''
  while [[ ! -s "$CMDER_CAPTURE_FILE" ]]; do
    # Drain terminal redraws so a full PTY buffer cannot block the child.
    while zpty -r cmder-interactive output 2>/dev/null; do
      transcript+=$output
      transcript=${transcript[-8192,-1]}
      if (( SECONDS >= deadline )); then break; fi
    done
    if (( SECONDS >= deadline )); then
      print -u2 -- "Interactive $shell: timed out capturing <$active_input>: $transcript"
      return 1
    fi
    zselect -t 1
  done
  return 0
}

check_buffer() {
  local input=$1 expected=$2 actual
  active_input=$input
  : > "$CMDER_CAPTURE_FILE"
  zpty -w -n cmder-interactive "$input"$'\t\C-x\C-r' || return 1
  wait_for_buffer || return 1
  actual=$(<"$CMDER_CAPTURE_FILE")
  if [[ "$actual" != "$expected" ]]; then
    print -u2 -r -- "Interactive $shell: expected <$expected>, got <$actual>"
    return 1
  fi
  ((checks += 1))
}

check_shell() {
  local shell=$1
  active_input=initialization
  export CMDER_COMPLETION_FILE="$CMDER_COMPLETION_ROOT/completion.$shell"
  : > "$CMDER_CAPTURE_FILE"
  {
    if [[ $shell == bash ]]; then
      zpty -b cmder-interactive bash --noprofile --norc -i || return 1
      zpty -w cmder-interactive 'source "$CMDER_COMPLETION_FILE"; cd "$CMDER_COMPLETION_FIXTURES"; set -o emacs; bind '\''"\C-i": complete'\''; _cmder_capture() { printf "%s\n" "$READLINE_LINE" > "$CMDER_CAPTURE_FILE"; READLINE_LINE=; READLINE_POINT=0; }; bind -x '\''"\C-x\C-r":_cmder_capture'\''; printf ready > "$CMDER_CAPTURE_FILE"' || return 1
    else
      # Exercise noninteractive startup even when fpath contains an insecure directory.
      local -x FPATH="$CMDER_INSECURE_FPATH:$FPATH"
      zpty -b cmder-interactive zsh -f || return 1
      zpty -w cmder-interactive 'autoload -Uz compinit; compinit -i -D; source "$CMDER_COMPLETION_FILE"; cd "$CMDER_COMPLETION_FIXTURES"; bindkey -e; _cmder_capture() { print -r -- "$BUFFER" > "$CMDER_CAPTURE_FILE"; BUFFER=; zle -R; }; zle -N cmder-capture _cmder_capture; bindkey "^X^R" cmder-capture; zle-line-init() { print -n ready > "$CMDER_CAPTURE_FILE"; }; zle -N zle-line-init' || return 1
    fi
    wait_for_buffer || return 1
    check_buffer 'cmder-test documents/quarter' 'cmder-test documents/quarter\ report.pptx ' || return 1
    check_buffer 'cmder-test files documents/quarter' 'cmder-test files documents/quarter\ report.pptx ' || return 1
    check_buffer 'cmder-test files -- documents/quarter' 'cmder-test files -- documents/quarter\ report.pptx ' || return 1
    check_buffer 'cmder-test files -- --lit' 'cmder-test files -- --literal.pptx ' || return 1
    check_buffer 'cmder-test files documents/quarter\ r' 'cmder-test files documents/quarter\ report.pptx ' || return 1
    check_buffer 'cmder-test files "documents/quarter' 'cmder-test files "documents/quarter report.pptx" ' || return 1
    check_buffer 'cmder-test db inspect --format documents/quarter' 'cmder-test db inspect --format documents/quarter\ report.pptx ' || return 1
    check_buffer 'cmder-test db inspect --format=documents/quarter' 'cmder-test db inspect --format=documents/quarter\ report.pptx ' || return 1
    if [[ $shell == zsh ]]; then
      check_buffer 'cmder-test db inspect -fdocuments/quarter' 'cmder-test db inspect -fdocuments/quarter\ report.pptx ' || return 1
    fi
  } always {
    # This named PTY belongs solely to this test invocation.
    zpty -d cmder-interactive 2>/dev/null
  }
}
for shell in bash zsh; do
  check_shell "$shell" || exit 1
done
printf 'Interactive shells: %s filename completion checks passed\n' "$checks"

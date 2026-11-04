source "$CMDER_COMPLETION_FILE"
set -g checks 0
function check
    set -l expected $argv[1]
    set -l actual (complete -C "$argv[2]" | string replace -r '\t.*$' '' | string match -- '--*' | sort | string join ' ')
    if test "$actual" != "$expected"
        printf 'Fish: %s: expected <%s>, got <%s>\n' "$argv[2]" "$expected" "$actual" >&2
        exit 1
    end
    set -g checks (math $checks + 1)
end
check '--verbose --version' 'cmder-test --v'
check --profile 'cmder-test --p'
check '--db-only --format --help' 'cmder-test db inspect --'
check '--cache-only --help' 'cmder-test cache inspect --'
check --db-only 'cmder-test --profile cache db inspect --db'
check --db-only 'cmder-test --profile=cache db inspect --db'
check --db-only 'cmder-test -vp cache db inspect --db'
check --db-only 'cmder-test -vpcache db inspect --db'
check --db-only 'cmder-test db --region cache inspect --db'
check '' 'cmder-test --profile --v'
check '' 'cmder-test db inspect --format --db'
check '' 'cmder-test files -- --f'
check '' 'cmder-test -- db inspect --db'
check '' 'cmder-test db -- inspect --db'
check '' 'cmder-test db inspect --v'
check --help 'cmder-test --h'
check --version 'cmder-test --vers'
check --help 'cmder-test files --h'
check --help 'cmder-test help db inspect --h'
check '' 'cmder-test help db inspect --db'
check '' 'cmder-test custom-help --help --h'
check --help 'cmder-test custom-short --hel'
check '' 'cmder-test custom-short -h --h'
set -l topics (complete -C 'cmder-test help db i' | string replace -r '\t.*$' '')
if not contains -- inspect $topics
    printf 'Fish: help topics did not follow the command hierarchy\n' >&2
    exit 1
end
set -g checks (math $checks + 1)
printf 'Fish: %s behavior checks passed\n' $checks

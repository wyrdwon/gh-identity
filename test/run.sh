#!/usr/bin/env bash
# Dependency-free test runner. Usage: test/run.sh
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
bin="$root/gh-identity"
passed=0 failed=0

setup() {
  sandbox=$(mktemp -d)
  export HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/config" XDG_STATE_HOME="$sandbox/state"
  export FAKE_GH_DIR="$sandbox/gh" GIT_CONFIG_NOSYSTEM=1
  export PATH="$root/test/bin:$PATH"
  unset GH_IDENTITY_CONFIG GH_IDENTITY_STATE_DIR GH_IDENTITY_HOST
  mkdir -p "$HOME" "$XDG_CONFIG_HOME/gh-identity" "$FAKE_GH_DIR"
  printf 'octo\nacme-octo\n' >"$FAKE_GH_DIR/logins"
  echo octo >"$FAKE_GH_DIR/active"
  cat >"$XDG_CONFIG_HOME/gh-identity/accounts" <<'EOF'
[account "personal"]
    user = octo
    email = octo@example.com
    name = Mona Octo
[account "work"]
    user = acme-octo
    email = mona@acme.test
    signingkey = ~/.ssh/work.pub
EOF
  state="$XDG_STATE_HOME/gh-identity"
}

not() { ! "$@"; }

teardown() { rm -rf "$sandbox"; }

# run <cmd...>: capture output and status into $out / $status.
run() {
  out=$("$@" 2>&1)
  status=$?
}

check() { # check <description> <condition...>
  local desc=$1
  shift
  if "$@"; then return 0; fi
  printf '    assertion failed: %s\n    output: %s\n' "$desc" "$out"
  return 1
}

# shellcheck disable=SC2088 # the literal "~" is what gets stored
test_use_switches_gh_and_writes_git_identity() {
  run "$bin" use work
  check "exit 0" [ "$status" -eq 0 ] &&
    check "gh switched" [ "$(cat "$FAKE_GH_DIR/active")" = acme-octo ] &&
    check "email written" [ "$(git config -f "$state/gitconfig" user.email)" = mona@acme.test ] &&
    check "name defaults to user" [ "$(git config -f "$state/gitconfig" user.name)" = acme-octo ] &&
    check "signingkey written" [ "$(git config -f "$state/gitconfig" user.signingkey)" = '~/.ssh/work.pub' ] &&
    check "current recorded" [ "$(cat "$state/current")" = work ]
}

test_use_drops_signingkey_from_previous_account() {
  "$bin" use work >/dev/null
  run "$bin" use personal
  check "exit 0" [ "$status" -eq 0 ] &&
    check "name set" [ "$(git config -f "$state/gitconfig" user.name)" = "Mona Octo" ] &&
    check "no stale signingkey" not git config -f "$state/gitconfig" user.signingkey
}

test_use_skips_gh_switch_when_already_active() {
  run "$bin" use personal
  check "exit 0" [ "$status" -eq 0 ] &&
    check "no switch call" not grep -q 'auth switch' "$FAKE_GH_DIR/calls" &&
    check "state still written" [ "$(cat "$state/current")" = personal ]
}

test_use_unknown_account_fails_and_lists_known() {
  run "$bin" use nope
  check "exit 1" [ "$status" -eq 1 ] &&
    check "names known accounts" grep -q 'known: personal work' <<<"$out" &&
    check "no state written" [ ! -e "$state/current" ]
}

test_use_fails_when_gh_not_logged_in() {
  echo octo >"$FAKE_GH_DIR/logins"
  run "$bin" use work
  check "exit 1" [ "$status" -eq 1 ] &&
    check "suggests login" grep -q 'gh auth login' <<<"$out" &&
    check "no state written" [ ! -e "$state/current" ]
}

test_current_and_list() {
  run "$bin" current
  check "current exits 1 before any use" [ "$status" -eq 1 ] || return 1
  "$bin" use work >/dev/null
  run "$bin" current
  check "current prints alias" [ "$out" = work ] || return 1
  run "$bin" list
  check "list marks active" grep -q '^\* work' <<<"$out" &&
    check "list shows other" grep -q '^  personal' <<<"$out"
}

test_missing_config_is_explained() {
  rm "$XDG_CONFIG_HOME/gh-identity/accounts"
  run "$bin" list
  check "exit 1" [ "$status" -eq 1 ] && check "mentions path" grep -q 'no config at' <<<"$out"
}

test_doctor_passes_when_wired() {
  printf '[user]\n\tname = old\n[include]\n\tpath = ~/.local/state/gh-identity/gitconfig\n' >"$HOME/.gitconfig"
  export XDG_STATE_HOME="$HOME/.local/state" && state="$XDG_STATE_HOME/gh-identity"
  "$bin" use work >/dev/null
  run "$bin" doctor
  check "exit 0" [ "$status" -eq 0 ] && check "no failures" not grep -q FAIL <<<"$out"
}

test_doctor_catches_user_section_after_include() {
  printf '[include]\n\tpath = %s/gitconfig\n[user]\n\temail = old@example.com\n' "$state" >"$HOME/.gitconfig"
  "$bin" use work >/dev/null
  run "$bin" doctor
  check "exit 1" [ "$status" -ne 0 ] && check "explains ordering" grep -q "after the include" <<<"$out"
}

test_doctor_catches_missing_include_and_login() {
  : >"$HOME/.gitconfig"
  echo octo >"$FAKE_GH_DIR/logins"
  run "$bin" doctor
  check "exit 1" [ "$status" -ne 0 ] &&
    check "missing include" grep -q 'add to ~/.gitconfig' <<<"$out" &&
    check "missing login" grep -q "work: gh is not logged in" <<<"$out"
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  setup
  if (set -e; "$t"); then
    passed=$((passed + 1))
    printf 'ok   %s\n' "$t"
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$t"
  fi
  teardown
done

printf '\n%d passed, %d failed\n' "$passed" "$failed"
((failed == 0))

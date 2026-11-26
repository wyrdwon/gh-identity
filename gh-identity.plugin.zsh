# gh-identity zsh integration. Optional: the gh extension works without it.
#
# Provides:
#   ghid ...                    shorthand for `gh identity ...`, with completion
#   <prefix><account>           per-account shortcuts, if GH_IDENTITY_SHORTCUT_PREFIX
#                               is set before sourcing (e.g. "git" gives `gitwork`)
#   gh_identity_current         prints the active account; no subprocess
#   prompt_gh_identity          powerlevel10k segment: add `gh_identity` to
#                               POWERLEVEL9K_{LEFT,RIGHT}_PROMPT_ELEMENTS
#   gh_identity_reload          re-read the config after editing it
#
# Works when loaded by a plugin manager (antidote, zinit, ...) or by `source`.

typeset -g _GH_IDENTITY_CONFIG="${GH_IDENTITY_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/gh-identity/accounts}"
typeset -g _GH_IDENTITY_CURRENT="${GH_IDENTITY_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/gh-identity}/current"

# Per-account settings, keyed "<account>.<key>" (e.g. "work.color").
typeset -gA _gh_identity_cfg
typeset -ga _gh_identity_accounts

# One `git config` call at load time; prompts never fork.
gh_identity_reload() {
  _gh_identity_cfg=()
  _gh_identity_accounts=()
  [[ -r $_GH_IDENTITY_CONFIG ]] || return 0

  local key value account
  while IFS=' ' read -r key value; do
    key=${key#account.}            # work.color
    account=${key%.*}
    _gh_identity_cfg[$key]=$value
    [[ ${key##*.} == user ]] && _gh_identity_accounts+=($account)
  done < <(git config --file "$_GH_IDENTITY_CONFIG" --get-regexp '^account\.' 2>/dev/null)

  if [[ -n $GH_IDENTITY_SHORTCUT_PREFIX ]]; then
    for account in $_gh_identity_accounts; do
      functions[$GH_IDENTITY_SHORTCUT_PREFIX$account]="gh identity use ${(q)account}"
    done
  fi
}

gh_identity_current() {
  [[ -r $_GH_IDENTITY_CURRENT ]] || return 1
  local alias
  alias=$(<$_GH_IDENTITY_CURRENT)
  [[ -n $alias ]] && print -r -- $alias
}

ghid() { gh identity "$@" }

_ghid() {
  local -a commands=(
    'use:switch gh and git to an account'
    'current:print the active account'
    'list:list configured accounts'
    'doctor:check config, gh logins and git wiring'
    'help:show help'
  )
  if (( CURRENT == 2 )); then
    _describe command commands
  elif [[ $words[2] == use ]] && (( CURRENT == 3 )); then
    compadd -a _gh_identity_accounts
  fi
}
(( $+functions[compdef] )) && compdef _ghid ghid

# --- powerlevel10k segment ---------------------------------------------------
# Colour and icon come from the account's `color` / `icon` keys, falling back
# to POWERLEVEL9K_GH_IDENTITY_FOREGROUND / POWERLEVEL9K_GH_IDENTITY_ICON.

prompt_gh_identity() {
  local alias
  [[ -r $_GH_IDENTITY_CURRENT ]] || return
  alias=$(<$_GH_IDENTITY_CURRENT)
  [[ -n $alias ]] || return

  local text=${_gh_identity_cfg[$alias.user]:-$alias}
  local fg=${_gh_identity_cfg[$alias.color]:-${POWERLEVEL9K_GH_IDENTITY_FOREGROUND:-244}}
  local icon=${_gh_identity_cfg[$alias.icon]:-${POWERLEVEL9K_GH_IDENTITY_ICON:-}}
  p10k segment -f "$fg" -i "$icon" -t "$text"
}

# Reading a file is instant, so instant prompt can use the same function.
instant_prompt_gh_identity() { prompt_gh_identity }

gh_identity_reload

# gh-identity

Switch GitHub accounts for the `gh` CLI **and** git's author identity in one
command, configured from a single file.

```console
$ gh identity use work
Using work: mona-acme, Mona Octocat <mona@acme.example>
$ gh identity list
  personal     octocat              Mona Octocat <octocat@example.com>
* work         mona-acme            Mona Octocat <mona@acme.example>
```

## How it works

- **One config file** (`~/.config/gh-identity/accounts`, git-config format)
  lists your accounts. Adding an account means adding a section, not code.
- `use` runs `gh auth switch`, then writes the identity (`user.name`,
  `user.email`, optional `user.signingkey`) to
  `~/.local/state/gh-identity/gitconfig`.
- Your `~/.gitconfig` **includes** that file. gh-identity never edits your
  gitconfig, so it stays clean in a dotfiles manager.
- State is in files, not environment variables, so a switch shows up at once
  in every open shell and prompt.

Requires only `bash`, `git` and `gh`.

## Install

```sh
gh extension install <owner>/gh-identity
```

## Setup

1. Log in to each account once: `gh auth login`
2. Create `~/.config/gh-identity/accounts`. See
   [`examples/accounts`](examples/accounts).
3. Add to `~/.gitconfig`, **after** any `[user]` section (later values win):
   ```ini
   [include]
       path = ~/.local/state/gh-identity/gitconfig
   ```
4. `gh identity use <account>`, then `gh identity doctor` to confirm the
   wiring.

## Commands

| Command | |
| --- | --- |
| `gh identity use <account>` | Switch gh and git to an account |
| `gh identity current` | Print the active account (exit 1 if none) |
| `gh identity list` | List accounts, `*` marks the active one |
| `gh identity doctor` | Check config, gh logins and gitconfig wiring |

`GH_IDENTITY_CONFIG`, `GH_IDENTITY_STATE_DIR` and `GH_IDENTITY_HOST`
(default `github.com`) override the defaults.

## zsh integration (optional)

Load `gh-identity.plugin.zsh` with your plugin manager (e.g. antidote:
`<owner>/gh-identity`) or `source` it. It provides:

- `ghid`, a shorthand for `gh identity`, with completion for subcommands and accounts.
- Per-account commands: set `GH_IDENTITY_SHORTCUT_PREFIX=git` before loading
  to get `gitpersonal`, `gitwork`, and so on.
- A **powerlevel10k segment**: add `gh_identity` to
  `POWERLEVEL9K_LEFT_PROMPT_ELEMENTS` (or right). Colour and icon come from
  each account's `color` / `icon` keys. The segment reads one file and starts
  no process, so it is safe for instant prompt.
- `gh_identity_current`, for use in other prompts.

Run `gh_identity_reload` after editing the config in an open shell.

## Development

```sh
test/run.sh          # no dependencies; uses a fake gh in test/bin
shellcheck gh-identity test/run.sh test/bin/gh
```

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

chezmoi source directory for macOS dotfiles. No build/test/lint — editing files here changes nothing until applied to `$HOME`. Bootstrap on a new machine: `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply cfsnate`.

## Core workflow

Edit source files in this repo, then apply to home:

```bash
chezmoi diff              # preview — opens Meld GUI, NOT terminal output
chezmoi status            # parseable diff summary; prefer this to `diff` when scripting/reading
chezmoi apply             # write changes to $HOME
chezmoi apply ~/.zshrc    # apply a single target
chezmoi execute-template < file.tmpl   # render a .tmpl to check output
chezmoi cd                # drop into this source dir
```

Do not edit files under `$HOME` directly — they are overwritten on next `apply`. Change the source file here instead. `chezmoi managed` lists everything chezmoi controls.

## Source-file naming (chezmoi attribute prefixes)

Filenames encode target path + permissions. Renaming changes behavior:

- `dot_X` → `.X`  (e.g. `dot_config/` → `~/.config/`)
- `private_X` → target gets `0600` perms
- `executable_X` → target gets `+x`
- `empty_X` → keep file even if empty
- `X.tmpl` → Go-template rendered with `.chezmoi*` data before write
- `run_once_before_*` / `run_once_after_*` → script runs once (hash-tracked), before/after the apply
- `run_onchange_*` → script re-runs whenever its (rendered) content changes

Templates use `{{ .name }}` / `{{ .email }}` from `.chezmoi.toml.tmpl` prompts and `{{ .packages.* }}` from `.chezmoidata/packages.yaml`.

## Key mechanisms

- **Package management**: `.chezmoidata/packages.yaml` is the source of truth (taps/formulae/casks). `run_install-packages.sh.tmpl` is a plain `run_` script, so it runs on every `chezmoi apply`: it does `brew update && brew upgrade`, then installs any tracked package that is missing (per-entry, not `brew bundle`, so one failure doesn't block the rest). To install/remove a package, edit the YAML; do not `brew install` ad hoc.
- **Drift detection**: `~/.local/bin/brew-diff` (source: `dot_local/bin/executable_brew-diff`) reports installed packages missing from `packages.yaml` and vice versa.
- **External deps**: `.chezmoiexternal.toml` clones zsh plugins/themes and tmux config into `~/.config/...` (refreshed every 168h). These are not vendored in git.
- **Secrets**: Slack token is read from the macOS Keychain via `{{ keyring "slack_status" "token" }}` in `private_dot_slack_status.conf.tmpl`. `run_once_before_ensure-slack-token.sh` prompts for it on first apply. Rotate: `chezmoi secret keyring set --service=slack_status --user=token`. Never hardcode the token in a source file.
- **Bootstrap script order**: `run_once_before` (homebrew install → omz install → slack token) run before files are written; `run_once_after` (set zsh as login shell → symlink oh-my-tmux config) run after.

## Shell config layout

zsh uses XDG dirs with `ZDOTDIR=~/.config/zsh` (set in `dot_config/zsh/dot_zshenv`, which is symlinked from `~/.zshenv` by the omz bootstrap script). Oh-My-Zsh lives at `$ZDOTDIR/.oh-my-zsh`; custom plugins/themes at `$ZDOTDIR/custom` are populated by `.chezmoiexternal.toml`, not tracked here. Main config: `dot_config/zsh/private_dot_zshrc`.

## Not chezmoi-managed

`.chezmoiignore` excludes `README.md` and `.mcp.json` from apply. `.gitignore` excludes `.mcp.json`, `.gsd/`, `.bg-shell/` from git. `.gsd/` (gsd-workflow MCP state) and `.bg-shell/` are local tooling — ignore them when reasoning about dotfiles.

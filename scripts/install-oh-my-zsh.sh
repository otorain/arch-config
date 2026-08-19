#!/usr/bin/env bash
# Install oh-my-zsh into ~/.oh-my-zsh (git clone). Idempotent: skipped when the
# directory already exists. install.sh runs this via as_user_home so $HOME is
# the target user's home; also works standalone.

set -euo pipefail

info() { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }

info "oh-my-zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi
ok "oh-my-zsh"

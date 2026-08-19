#!/usr/bin/env bash
# Install the catppuccin fcitx5 theme (mocha blue) from GitHub into the target
# user's fcitx5 themes dir, with rounded corners enabled. Idempotent: skipped
# when the theme dir already exists. Derives the target user/home itself, so it
# works both when invoked by install.sh (possibly as root via sudo) and standalone.

set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

info() { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }

info "fcitx5 catppuccin theme"
themes_dir="$TARGET_HOME/.local/share/fcitx5/themes"
if [[ ! -d "$themes_dir/catppuccin-mocha-blue" ]]; then
  tmp="$(mktemp -d)"
  git clone --depth 1 https://github.com/catppuccin/fcitx5.git "$tmp/fcitx5"
  mkdir -p "$themes_dir"
  cp -r "$tmp/fcitx5/src/catppuccin-mocha-blue" "$themes_dir/catppuccin-mocha-blue"
  # rounded corners
  (cd "$themes_dir/catppuccin-mocha-blue" &&
    bash "$tmp/fcitx5/enable-rounded.sh" 2>/dev/null) || true
  rm -rf "$tmp"
  chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local/share/fcitx5"
fi
ok "fcitx5 theme"

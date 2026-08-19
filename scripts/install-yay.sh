#!/usr/bin/env bash
# Bootstrap yay (AUR helper): clone yay-bin from the AUR and build it with
# makepkg. Idempotent — exits early when yay is already on PATH.
# Run as a normal user (makepkg refuses to run as root); install.sh calls this
# in the invoking user's context, and it also works standalone.

set -euo pipefail

info() { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31m  ✗ %s\033[0m\n' "$*" >&2
  exit 1
}

info "installing yay"
if command -v yay &>/dev/null; then
  ok "yay already installed"
  exit 0
fi
[[ "$(id -u)" -ne 0 ]] || die "run as a normal user (makepkg refuses to run as root)"

tmp="$(mktemp -d)"
git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
(cd "$tmp/yay-bin" && makepkg -si --noconfirm)
rm -rf "$tmp"
ok "yay installed"

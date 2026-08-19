#!/usr/bin/env bash
# Install try-cli (github.com/tobi/try, Ruby) into ~/.local/share/try-cli and
# generate the ~/.local/bin/try wrapper. Idempotent. install.sh runs this via
# as_user_home so $HOME is the target user's home; also works standalone.

set -euo pipefail

info() { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }

info "try-cli"
if [[ ! -d "$HOME/.local/share/try-cli" ]]; then
  git clone --depth 1 https://github.com/tobi/try.git "$HOME/.local/share/try-cli" ||
    warn "try-cli clone failed, install manually later: https://github.com/tobi/try"
fi
if [[ -d "$HOME/.local/share/try-cli" && ! -x "$HOME/.local/bin/try" ]]; then
  mkdir -p "$HOME/.local/bin"
  tee "$HOME/.local/bin/try" >/dev/null <<'EOF'
#!/bin/sh
exec ruby "$HOME/.local/share/try-cli/try.rb" "$@"
EOF
  chmod +x "$HOME/.local/bin/try"
fi
ok "try-cli"

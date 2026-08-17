#!/usr/bin/env bash
# Arch Linux (Hyprland) environment setup script
#
# Usage:
#   ./install.sh              # run all stages
#   ./install.sh --only pacman,aur,dotfiles   # run only specified stages
#
# Stages: preflight → pacman → yay → aur → system → services
#       → user → dotfiles → themes → mpv → post
#
# Idempotent; existing configs are overwritten without backup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

# --- output ---
info() { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31m  ✗ %s\033[0m\n' "$*" >&2
  exit 1
}

# --- stage selection ---
ONLY=""
if [[ "${1:-}" == "--only" ]]; then
  ONLY="${2:?usage: --only stage1,stage2}"
fi
should_run() { [[ -z "$ONLY" ]] || [[ ",$ONLY," == *",$1,"* ]]; }

as_user() { # run as target user (handles sudo case)
  if [[ "$USER" == "$TARGET_USER" && -z "${SUDO_USER:-}" ]]; then
    "$@"
  else
    sudo -u "$TARGET_USER" "$@"
  fi
}

as_user_home() { as_user env HOME="$TARGET_HOME" "$@"; }

read_packages() { # read package list, strip comments and blank lines
  grep -vE '^\s*(#|$)' "$SCRIPT_DIR/packages/$1"
}

# ========== stages ==========

preflight() {
  info "Preflight"
  [[ -f /etc/arch-release ]] || die "this script only supports Arch Linux"
  [[ "$TARGET_USER" != "root" ]] || die "run as a normal user (not directly as root)"
  command -v sudo >/dev/null || die "sudo is required"
  ping -c1 -W3 archlinux.org &>/dev/null || die "no network connection"
  ok "Arch Linux, user $TARGET_USER, HOME=$TARGET_HOME"
}

pacman_pkgs() {
  info "installing official repo packages"
  local pkgs=()
  mapfile -t pkgs < <(read_packages pacman.txt)
  sudo pacman -S --needed --noconfirm "${pkgs[@]}"
  ok "pacman done"
}

install_yay() {
  info "installing yay"
  if command -v yay &>/dev/null; then
    ok "yay already installed"
    return
  fi
  local tmp
  tmp="$(mktemp -d)"
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
  ok "yay installed"
}

aur_pkgs() {
  info "installing AUR packages (unresolvable ones are skipped)"
  local failed=()
  while read -r pkg; do
    if yay -Si "$pkg" &>/dev/null; then
      yay -S --needed --noconfirm "$pkg" || {
        warn "install failed: $pkg"
        failed+=("$pkg")
      }
    else
      warn "not in AUR (skipped): $pkg"
      failed+=("$pkg")
    fi
  done < <(read_packages aur.txt)
  if ((${#failed[@]})); then
    warn "these packages failed to install, handle manually: ${failed[*]}"
  fi
  ok "AUR stage done"
}

system_config() {
  info "writing system config"

  # timezone
  sudo timedatectl set-timezone Asia/Shanghai

  # locale: generate en_US.UTF-8 + zh_CN.UTF-8; default Chinese UI, English terminal messages
  sudo sed -i -E 's/^#(en_US.UTF-8 UTF-8)/\1/; s/^#(zh_CN.UTF-8 UTF-8)/\1/' /etc/locale.gen
  sudo locale-gen
  sudo tee /etc/locale.conf >/dev/null <<'EOF'
LANG=zh_CN.UTF-8
LC_MESSAGES=en_US.UTF-8
EOF

  # zram
  sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF

  # SSH hardening
  sudo tee /etc/ssh/sshd_config.d/99-hardening.conf >/dev/null <<'EOF'
PermitRootLogin no
EOF

  # SDDM catppuccin theme + wallpaper (AUR packages provide catppuccin-mocha-<accent> variants)
  local sddm_theme=""
  for d in /usr/share/sddm/themes/catppuccin-mocha-blue /usr/share/sddm/themes/catppuccin-mocha-*; do
    [[ -d "$d" ]] && sddm_theme="$d" && break
  done
  if [[ -n "$sddm_theme" ]]; then
    sudo cp "$SCRIPT_DIR/assets/colin-watts.jpg" \
      "$sddm_theme/backgrounds/wallpaper.jpg"
    # point theme background at wallpaper
    if [[ -f "$sddm_theme/theme.conf" ]]; then
      sudo sed -i -E 's|^Background=.*|Background="backgrounds/wallpaper.jpg"|; s|^background=.*|background="backgrounds/wallpaper.jpg"|' \
        "$sddm_theme/theme.conf"
    fi
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null <<EOF
[Theme]
Current=$(basename "$sddm_theme")
EOF
    ok "SDDM theme configured: $(basename "$sddm_theme")"
  else
    warn "catppuccin-mocha SDDM theme dir not found, skipping (AUR package not installed?)"
  fi

  ok "system config done"
}

services() {
  info "enabling systemd services"
  local sys_units=(
    NetworkManager
    bluetooth
    sshd
    fail2ban
    cups.socket
    avahi-daemon
    udisks2
    earlyoom
    fstrim.timer
    docker.socket
    libvirtd.socket
    sddm
  )
  for u in "${sys_units[@]}"; do
    sudo systemctl enable --now "$u" &>/dev/null && ok "$u" || warn "enable failed: $u"
  done

  # user-level audio services
  as_user systemctl --user enable --now pipewire pipewire-pulse wireplumber &>/dev/null || true
  ok "user audio services"
}

user_setup() {
  info "user setup"
  # user groups
  sudo usermod -aG wheel,docker,vboxusers,libvirt "$TARGET_USER"
  ok "user groups: wheel docker vboxusers libvirt"

  # default shell → zsh
  if [[ "$(getent passwd "$TARGET_USER" | cut -d: -f7)" != */zsh ]]; then
    as_user chsh -s /usr/bin/zsh || sudo chsh -s /usr/bin/zsh "$TARGET_USER"
  fi
  ok "shell = zsh"

  # oh-my-zsh
  if [[ ! -d "$TARGET_HOME/.oh-my-zsh" ]]; then
    as_user_home git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$TARGET_HOME/.oh-my-zsh"
  fi
  ok "oh-my-zsh"

  # npm global prefix (no sudo), used by codex / pi-coding-agent
  as_user_home npm config set prefix "$TARGET_HOME/.local" 2>/dev/null || true
  ok "npm prefix = ~/.local"
}

dotfiles() {
  info "copying dotfiles (existing files overwritten)"
  (cd "$SCRIPT_DIR/dotfiles" && find . -type f) | while read -r f; do
    local_rel="${f#./}"
    src="$SCRIPT_DIR/dotfiles/$local_rel"
    dest="$TARGET_HOME/$local_rel"
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
  done
  # wallpaper
  cp -a "$SCRIPT_DIR/assets/colin-watts.jpg" "$TARGET_HOME/.config/hypr/wallpaper.jpg"
  chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config" "$TARGET_HOME/.local/share" \
    "$TARGET_HOME/.zshrc" "$TARGET_HOME/.pi" "$TARGET_HOME/.gtkrc-2.0" 2>/dev/null || true

  # refresh desktop entry/icon caches so web-app .desktop files are searchable immediately
  as_user_home update-desktop-database "$TARGET_HOME/.local/share/applications" 2>/dev/null || true
  as_user_home gtk-update-icon-cache -f "$TARGET_HOME/.local/share/icons/hicolor" 2>/dev/null || true

  # git identity: ~/.config/git/config is user-owned (generated once, never overwritten);
  # it includes ~/.config/git/custom, which is managed by dotfiles (delta + catppuccin)
  local git_config="$TARGET_HOME/.config/git/config"
  if [[ -f "$git_config" ]]; then
    if ! grep -q 'config/git/custom' "$git_config"; then
      # shellcheck disable=SC2088 # tilde is literal text for the git config include path
      warn "~/.config/git/config lacks the include of ~/.config/git/custom; add: [include] path = ~/.config/git/custom"
    fi
    ok "git config already exists (left untouched)"
  else
    local git_name="" git_email=""
    if [[ -t 0 ]]; then
      read -rp "  git user.name: " git_name
      read -rp "  git user.email: " git_email
    fi
    {
      if [[ -n "$git_name" || -n "$git_email" ]]; then
        echo "[user]"
        [[ -z "$git_name" ]] || printf '\tname = %s\n' "$git_name"
        [[ -z "$git_email" ]] || printf '\temail = %s\n' "$git_email"
        echo
      fi
      echo "# shared settings managed by dotfiles (delta, catppuccin theme) - do not edit"
      echo "[include]"
      printf '\tpath = ~/.config/git/custom\n'
    } | as_user_home tee "$git_config" >/dev/null
    if [[ -n "$git_name" && -n "$git_email" ]]; then
      ok "git identity saved to ~/.config/git/config"
    else
      warn "created ~/.config/git/config without [user]; add user.name/user.email manually"
    fi
  fi

  ok "dotfiles done"
}

themes() {
  info "installing themes"

  # fcitx5 catppuccin theme
  if [[ ! -d "$TARGET_HOME/.local/share/fcitx5/themes/catppuccin-mocha-blue" ]]; then
    local tmp
    tmp="$(mktemp -d)"
    git clone --depth 1 https://github.com/catppuccin/fcitx5.git "$tmp/fcitx5"
    mkdir -p "$TARGET_HOME/.local/share/fcitx5/themes"
    cp -r "$tmp/fcitx5/src/catppuccin-mocha-blue" \
      "$TARGET_HOME/.local/share/fcitx5/themes/catppuccin-mocha-blue"
    # rounded corners
    (cd "$TARGET_HOME/.local/share/fcitx5/themes/catppuccin-mocha-blue" &&
      bash "$tmp/fcitx5/enable-rounded.sh" 2>/dev/null) || true
    rm -rf "$tmp"
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local/share/fcitx5"
  fi
  ok "fcitx5 theme"

  # GTK4 / Libadwaita links
  local gtk_theme=""
  for d in "$TARGET_HOME/.themes/Colloid-Dark-Catppuccin" /usr/share/themes/Colloid-Dark-Catppuccin; do
    [[ -d "$d" ]] && gtk_theme="$d" && break
  done
  if [[ -n "$gtk_theme" && -d "$gtk_theme/gtk-4.0" ]]; then
    mkdir -p "$TARGET_HOME/.config/gtk-4.0"
    for f in assets gtk.css gtk-dark.css; do
      ln -sfn "$gtk_theme/gtk-4.0/$f" "$TARGET_HOME/.config/gtk-4.0/$f"
    done
    ok "GTK4 theme links → $gtk_theme"
  else
    warn "Colloid-Dark-Catppuccin theme not found, skipping GTK4 links"
  fi

  # write GTK dark preference to gsettings (portal takes precedence over settings.ini; GTK3/4 and Chrome all read it)
  local uid bus
  uid="$(id -u "$TARGET_USER")"
  bus="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$uid/bus}"
  if [[ -n "$gtk_theme" ]] || [[ -d /usr/share/themes/Colloid-Dark-Catppuccin ]]; then
    as_user_home env DBUS_SESSION_BUS_ADDRESS="$bus" \
      gsettings set org.gnome.desktop.interface gtk-theme 'Colloid-Dark-Catppuccin' || warn "gsettings gtk-theme failed"
    as_user_home env DBUS_SESSION_BUS_ADDRESS="$bus" \
      gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || warn "gsettings icon-theme failed"
    as_user_home env DBUS_SESSION_BUS_ADDRESS="$bus" \
      gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || warn "gsettings color-scheme failed"
    as_user_home env DBUS_SESSION_BUS_ADDRESS="$bus" \
      gsettings set org.gnome.desktop.interface font-name 'Noto Sans 12' || warn "gsettings font-name failed"
    ok "gsettings: Colloid-Dark-Catppuccin / Papirus-Dark / prefer-dark / Noto Sans"
  fi

  # refresh font/icon caches
  fc-cache -f &>/dev/null || true
  ok "themes done"
}

mpv_scripts() {
  info "setting up mpv scripts (uosc / thumbfast / sponsorblock)"
  mkdir -p "$TARGET_HOME/.config/mpv/scripts"
  local linked=0
  for s in /usr/share/mpv/scripts/*; do
    [[ -e "$s" ]] || continue
    ln -sfn "$s" "$TARGET_HOME/.config/mpv/scripts/"
    linked=$((linked + 1))
  done
  chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/mpv"
  ok "linked $linked mpv scripts"
}

post() {
  info "post-install"

  # npm global tools (codex CLI, pi-coding-agent)
  as_user_home npm i -g @openai/codex @mariozechner/pi-coding-agent ||
    warn "npm global install failed, do it manually later: npm i -g @openai/codex @mariozechner/pi-coding-agent"

  # rustup default toolchain
  as_user_home rustup default stable || warn "rustup default stable failed"

  # try-cli: manage experimental directories
  if [[ ! -d "$TARGET_HOME/.local/share/try-cli" ]]; then
    as_user_home git clone --depth 1 https://github.com/tobi/try.git \
      "$TARGET_HOME/.local/share/try-cli" ||
      warn "try-cli clone failed, install manually later: https://github.com/tobi/try"
  fi
  if [[ -d "$TARGET_HOME/.local/share/try-cli" && ! -x "$TARGET_HOME/.local/bin/try" ]]; then
    as_user_home mkdir -p "$TARGET_HOME/.local/bin"
    as_user_home tee "$TARGET_HOME/.local/bin/try" >/dev/null <<'EOF'
#!/bin/sh
exec ruby "$HOME/.local/share/try-cli/try.rb" "$@"
EOF
    as_user chmod +x "$TARGET_HOME/.local/bin/try"
  fi
  ok "try-cli"

  # xdg user directories
  as_user_home xdg-user-dirs-update || true
  mkdir -p "$TARGET_HOME/Projects" "$TARGET_HOME/Pictures/mpv" "$TARGET_HOME/src/tries"

  # bat theme cache (skipped if catppuccin comes from a system package)
  as_user_home bat cache --build &>/dev/null || true

  ok "done"
}

# ========== main flow ==========

main() {
  should_run preflight && preflight
  should_run pacman && pacman_pkgs
  should_run yay && install_yay
  should_run aur && aur_pkgs
  should_run system && system_config
  should_run services && services
  should_run user && user_setup
  should_run dotfiles && dotfiles
  should_run themes && themes
  should_run mpv && mpv_scripts
  should_run post && post

  echo
  info "All done!"
  echo "  1. reboot or re-login to apply zsh / user groups"
  echo "  2. for monitor name/scale, edit the hl.monitor line at the top of ~/.config/hypr/hyprland.lua (check with hyprctl monitors)"
}

main "$@"

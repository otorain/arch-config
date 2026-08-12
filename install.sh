#!/usr/bin/env bash
# Arch Linux (Hyprland) 环境安装脚本
#
# 用法:
#   ./install.sh              # 全部阶段
#   ./install.sh --only pacman,aur,dotfiles   # 只跑指定阶段
#
# 阶段: preflight → pacman → yay → aur → system → services
#       → user → dotfiles → themes → mpv → post
#
# 幂等，可重复运行；已有配置直接覆盖，不备份

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

# --- 输出 ---
info() { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31m  ✗ %s\033[0m\n' "$*" >&2
  exit 1
}

# --- 阶段选择 ---
ONLY=""
if [[ "${1:-}" == "--only" ]]; then
  ONLY="${2:?用法: --only stage1,stage2}"
fi
should_run() { [[ -z "$ONLY" ]] || [[ ",$ONLY," == *",$1,"* ]]; }

as_user() { # 以目标用户身份运行（处理 sudo 场景）
  if [[ "$USER" == "$TARGET_USER" && -z "${SUDO_USER:-}" ]]; then
    "$@"
  else
    sudo -u "$TARGET_USER" "$@"
  fi
}

as_user_home() { as_user env HOME="$TARGET_HOME" "$@"; }

read_packages() { # 读取包清单，去掉注释和空行
  grep -vE '^\s*(#|$)' "$SCRIPT_DIR/packages/$1"
}

# ========== 阶段 ==========

preflight() {
  info "预检"
  [[ -f /etc/arch-release ]] || die "此脚本只支持 Arch Linux"
  [[ "$TARGET_USER" != "root" ]] || die "请以普通用户运行（不要直接用 root）"
  command -v sudo >/dev/null || die "需要 sudo"
  ping -c1 -W3 archlinux.org &>/dev/null || die "无网络连接"
  ok "Arch Linux, 用户 $TARGET_USER, HOME=$TARGET_HOME"
}

pacman_pkgs() {
  info "安装官方仓库软件包"
  local pkgs=()
  mapfile -t pkgs < <(read_packages pacman.txt)
  sudo pacman -S --needed --noconfirm "${pkgs[@]}"
  ok "pacman 完成"
}

install_yay() {
  info "安装 yay"
  if command -v yay &>/dev/null; then
    ok "yay 已存在"
    return
  fi
  local tmp
  tmp="$(mktemp -d)"
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
  ok "yay 安装完成"
}

aur_pkgs() {
  info "安装 AUR 软件包（探测失败的会跳过）"
  local failed=()
  while read -r pkg; do
    if yay -Si "$pkg" &>/dev/null; then
      yay -S --needed --noconfirm "$pkg" || {
        warn "安装失败: $pkg"
        failed+=("$pkg")
      }
    else
      warn "AUR 中不存在（跳过）: $pkg"
      failed+=("$pkg")
    fi
  done < <(read_packages aur.txt)
  if ((${#failed[@]})); then
    warn "以下包未成功安装，请手工处理: ${failed[*]}"
  fi
  ok "AUR 阶段完成"
}

system_config() {
  info "写入系统配置"

  # 时区
  sudo timedatectl set-timezone Asia/Shanghai

  # locale：生成 en_US.UTF-8 + zh_CN.UTF-8，默认中文界面、英文终端报错
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

  # SSH 加固
  sudo tee /etc/ssh/sshd_config.d/99-hardening.conf >/dev/null <<'EOF'
PermitRootLogin no
EOF

  # SDDM catppuccin 主题 + 壁纸（AUR 包提供 catppuccin-mocha-<accent> 变体）
  local sddm_theme=""
  for d in /usr/share/sddm/themes/catppuccin-mocha-blue /usr/share/sddm/themes/catppuccin-mocha-*; do
    [[ -d "$d" ]] && sddm_theme="$d" && break
  done
  if [[ -n "$sddm_theme" ]]; then
    sudo cp "$SCRIPT_DIR/assets/colin-watts.jpg" \
      "$sddm_theme/backgrounds/wallpaper.jpg"
    # 主题背景指向壁纸
    if [[ -f "$sddm_theme/theme.conf" ]]; then
      sudo sed -i -E 's|^Background=.*|Background="backgrounds/wallpaper.jpg"|; s|^background=.*|background="backgrounds/wallpaper.jpg"|' \
        "$sddm_theme/theme.conf"
    fi
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null <<EOF
[Theme]
Current=$(basename "$sddm_theme")
EOF
    ok "SDDM 主题已配置: $(basename "$sddm_theme")"
  else
    warn "未找到 catppuccin-mocha SDDM 主题目录，跳过（AUR 包未装？）"
  fi

  ok "系统配置完成"
}

services() {
  info "启用 systemd 服务"
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
    sudo systemctl enable --now "$u" &>/dev/null && ok "$u" || warn "启用失败: $u"
  done

  # 用户级音频服务
  as_user systemctl --user enable --now pipewire pipewire-pulse wireplumber &>/dev/null || true
  ok "用户音频服务"
}

user_setup() {
  info "用户配置"
  # 用户组
  sudo usermod -aG wheel,docker,vboxusers,libvirt "$TARGET_USER"
  ok "用户组: wheel docker vboxusers libvirt"

  # 默认 shell → zsh
  if [[ "$(getent passwd "$TARGET_USER" | cut -d: -f7)" != */zsh ]]; then
    as_user chsh -s /usr/bin/zsh || sudo chsh -s /usr/bin/zsh "$TARGET_USER"
  fi
  ok "shell = zsh"

  # oh-my-zsh
  if [[ ! -d "$TARGET_HOME/.oh-my-zsh" ]]; then
    as_user_home git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$TARGET_HOME/.oh-my-zsh"
  fi
  ok "oh-my-zsh"

  # npm 全局目录（免 sudo），供 codex / pi-coding-agent 使用
  as_user_home npm config set prefix "$TARGET_HOME/.local" 2>/dev/null || true
  ok "npm prefix = ~/.local"
}

dotfiles() {
  info "复制配置文件（已有文件直接覆盖）"
  (cd "$SCRIPT_DIR/dotfiles" && find . -type f) | while read -r f; do
    local_rel="${f#./}"
    src="$SCRIPT_DIR/dotfiles/$local_rel"
    dest="$TARGET_HOME/$local_rel"
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
  done
  # 壁纸
  cp -a "$SCRIPT_DIR/assets/colin-watts.jpg" "$TARGET_HOME/.config/hypr/wallpaper.jpg"
  chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config" "$TARGET_HOME/.local/share" \
    "$TARGET_HOME/.zshrc" "$TARGET_HOME/.pi" 2>/dev/null || true

  # 刷新桌面项/图标缓存，网页应用 .desktop 即刻可搜
  as_user_home update-desktop-database "$TARGET_HOME/.local/share/applications" 2>/dev/null || true
  as_user_home gtk-update-icon-cache -f "$TARGET_HOME/.local/share/icons/hicolor" 2>/dev/null || true

  ok "dotfiles 完成"
}

themes() {
  info "安装主题"

  # fcitx5 catppuccin 主题
  if [[ ! -d "$TARGET_HOME/.local/share/fcitx5/themes/catppuccin-mocha-blue" ]]; then
    local tmp
    tmp="$(mktemp -d)"
    git clone --depth 1 https://github.com/catppuccin/fcitx5.git "$tmp/fcitx5"
    mkdir -p "$TARGET_HOME/.local/share/fcitx5/themes"
    cp -r "$tmp/fcitx5/src/catppuccin-mocha-blue" \
      "$TARGET_HOME/.local/share/fcitx5/themes/catppuccin-mocha-blue"
    # 圆角
    (cd "$TARGET_HOME/.local/share/fcitx5/themes/catppuccin-mocha-blue" &&
      bash "$tmp/fcitx5/enable-rounded.sh" 2>/dev/null) || true
    rm -rf "$tmp"
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local/share/fcitx5"
  fi
  ok "fcitx5 主题"

  # GTK4 / Libadwaita 链接
  local gtk_theme=""
  for d in "$TARGET_HOME/.themes/Colloid-Dark-Catppuccin" /usr/share/themes/Colloid-Dark-Catppuccin; do
    [[ -d "$d" ]] && gtk_theme="$d" && break
  done
  if [[ -n "$gtk_theme" && -d "$gtk_theme/gtk-4.0" ]]; then
    mkdir -p "$TARGET_HOME/.config/gtk-4.0"
    for f in assets gtk.css gtk-dark.css; do
      ln -sfn "$gtk_theme/gtk-4.0/$f" "$TARGET_HOME/.config/gtk-4.0/$f"
    done
    ok "GTK4 主题链接 → $gtk_theme"
  else
    warn "未找到 Colloid-Dark-Catppuccin 主题，GTK4 链接跳过"
  fi

  # GTK 深色偏好写入 gsettings（portal 优先于 settings.ini，GTK3/4 与 Chrome 都读它）
  local uid bus
  uid="$(id -u "$TARGET_USER")"
  bus="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$uid/bus}"
  if [[ -n "$gtk_theme" ]] || [[ -d /usr/share/themes/Colloid-Dark-Catppuccin ]]; then
    as_user_home env DBUS_SESSION_BUS_ADDRESS="$bus" \
      gsettings set org.gnome.desktop.interface gtk-theme 'Colloid-Dark-Catppuccin' || warn "gsettings gtk-theme 失败"
    as_user_home env DBUS_SESSION_BUS_ADDRESS="$bus" \
      gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || warn "gsettings icon-theme 失败"
    as_user_home env DBUS_SESSION_BUS_ADDRESS="$bus" \
      gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || warn "gsettings color-scheme 失败"
    ok "gsettings: Colloid-Dark-Catppuccin / Papirus-Dark / prefer-dark"
  fi

  # 刷新字体/图标缓存
  fc-cache -f &>/dev/null || true
  ok "主题完成"
}

mpv_scripts() {
  info "配置 mpv 脚本（uosc / thumbfast / sponsorblock）"
  mkdir -p "$TARGET_HOME/.config/mpv/scripts"
  local linked=0
  for s in /usr/share/mpv/scripts/*; do
    [[ -e "$s" ]] || continue
    ln -sfn "$s" "$TARGET_HOME/.config/mpv/scripts/"
    linked=$((linked + 1))
  done
  chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/mpv"
  ok "链接了 $linked 个 mpv 脚本"
}

post() {
  info "收尾"

  # npm 全局工具（codex CLI、pi-coding-agent）
  as_user_home npm i -g @openai/codex @mariozechner/pi-coding-agent ||
    warn "npm 全局安装失败，可稍后手动: npm i -g @openai/codex @mariozechner/pi-coding-agent"

  # rustup 默认工具链
  as_user_home rustup default stable || warn "rustup default stable 失败"

  # try-cli 实验目录管理
  if [[ ! -d "$TARGET_HOME/.local/share/try-cli" ]]; then
    as_user_home git clone --depth 1 https://github.com/tobi/try.git \
      "$TARGET_HOME/.local/share/try-cli" ||
      warn "try-cli 克隆失败，可稍后手动安装: https://github.com/tobi/try"
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

  # xdg 用户目录
  as_user_home xdg-user-dirs-update || true
  mkdir -p "$TARGET_HOME/Projects" "$TARGET_HOME/Pictures/mpv" "$TARGET_HOME/src/tries"

  # bat 主题缓存（catppuccin 由系统包提供则跳过）
  as_user_home bat cache --build &>/dev/null || true

  ok "完成"
}

# ========== 主流程 ==========

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
  info "全部完成！"
  echo "  1. 重启或重新登录使 zsh / 用户组生效"
  echo "  2. 显示器名称/缩放请编辑 ~/.config/hypr/hyprland.lua 顶部的 hl.monitor 行（hyprctl monitors 查看）"
}

main "$@"

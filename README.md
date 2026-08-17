[English](README.md) | [中文](README.zh.md)

![arch-config screenshot](assets/screenshot.png)

# arch-config — personal Arch Linux (Hyprland) system config

Personal Arch Linux (Hyprland) desktop environment config: install script + config files in one repo, catppuccin-mocha (blue) theme.

## Usage

First install the base system with archinstall (see "Base install" below), then:

```bash
git clone <your-repo> ~/arch-config
cd ~/arch-config
./install.sh
```

Re-running is safe. To run only some stages:

```bash
./install.sh --only pacman,aur        # install packages only
./install.sh --only dotfiles,themes   # deploy configs only
```

Stage order: `preflight → pacman → yay → aur → system → services → user → dotfiles → themes → mpv → post`

## Base install (archinstall suggestions)

- If you use btrfs, install `compsize` afterwards
- Mirrors: `reflector --country China --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist`
- The timezone script sets Asia/Shanghai; the locale script generates en_US.UTF-8 + zh_CN.UTF-8, default `LANG=zh_CN.UTF-8` (terminal errors stay in English via `LC_MESSAGES=en_US.UTF-8`)

## Desktop components

- hyprland + waybar (window manager / status bar)
- hyprlock + hypridle (lock / idle screen off)
- hyprpaper (wallpaper)
- rofi (app / emoji launcher)
- grim + slurp + satty (screenshot annotation)
- hyprpicker (color picker)
- wl-clipboard + cliphist (clipboard)
- dunst (notifications)
- nwg-look (GTK appearance settings)
- hyprpolkitagent (polkit agent)
- sddm (login manager, catppuccin theme)

## Manual steps after install

1. **Monitor**: check the interface name with `hyprctl monitors`, then edit the `hl.monitor({...})` line at the top of `~/.config/hypr/hyprland.lua` (Hyprland 0.55 dropped hyprlang, the config is the Lua version). Default is `DP-1` + scale 1.25; external monitors usually use 1
2. **neovim**: config is deployed with the dotfiles (LazyVim); on first launch it auto-installs plugins and compiles tree-sitter grammars (needs gcc, already in the package list)
3. **Input method**: fcitx5 autostarts after re-login; rime auto-deploys rime-ice on first run. To keep your old word-frequency data, copy `~/.local/share/fcitx5/rime/*.userdb` from the old system
4. **dropbox**: `hl.exec_cmd("dropbox")` is commented out in hyprland.lua; uncomment it after installing the AUR package
5. **VirtualBox**: extension pack in AUR `virtualbox-ext-oracle`; if modules break after a kernel update, run `sudo vboxreload`
6. **goldendict-ng**: dictionaries must be placed manually, see the [Dictionaries](https://github.com/xiaoyifang/goldendict-ng?tab=readme-ov-file#dictionaries) docs (put dictionary files under `~/.local/share/goldendict`, then add the directory in settings). Autostarts in the tray at login; `Super+T` forwards the query through single-instance IPC, avoiding cold start
7. **git**: on the first dotfiles run you're asked for `user.name`/`user.email`, saved to `~/.config/git/config` — that file is yours and is never overwritten on re-runs. Shared settings (delta, catppuccin theme) live in `~/.config/git/custom`, which is managed by dotfiles; don't edit it

## Keybindings

| Shortcut | Action |
| --- | --- |
| `Super+Return` | Terminal |
| `Super+D` | App launcher |
| `Super+E` | Emoji picker |
| `Super+Ctrl+C` | Browser (Chrome) |
| `Super+Ctrl+F` | Firefox |
| `Super+Ctrl+R` | RubyMine |
| `Super+Ctrl+P` | PyCharm |
| `Super+F3` | File manager (pcmanfm) |
| `Super+T` | Look up selected text (goldendict) |
| `Super+O` | Clipboard history (cliphist + rofi) |
| `Super+C` | Color picker (hyprpicker, auto-copy) |
| `Super+P` | Region screenshot (satty annotation) |
| `Print` | Fullscreen screenshot |
| `Shift+Print` | Region screenshot (no annotation) |
| `Super+Q` | DeepSeek scratchpad |
| ``Super+` `` | Kimi scratchpad |
| `Super+Shift+Q` | Close window |
| `Super+F` | Fullscreen |
| `Super+Shift+Space` | Toggle floating |
| `Super+W` | Tab group |
| `Super+V` | Preset split (bottom) |
| `Super+;` | Preset split (right) |
| `Super+H/J/K/L` | Focus (with arrow keys) |
| `Super+Shift+H/J/K/L` | Move window (with arrow keys) |
| `Alt+Tab` | Previous workspace |
| `Super+Ctrl+←/→` | Adjacent workspace |
| `Super+1..9` | Workspace |
| `Super+Shift+1..9` | Move to workspace |
| `Super+scroll` | Switch workspace |
| `Super+LMB` | Drag window |
| `Super+RMB` | Resize window |
| `Super+R` | Resize mode (H/J/K/L to adjust, Enter/Esc to exit) |
| `Super+Ctrl+L` | Lock screen |
| `Super+0` | Power menu |
| `Super+Shift+E` | Exit Hyprland |
| `Super+M` | Show/hide status bar |
| `Super+Shift+D` | Restart dunst |
| `Super+Shift+C` | Reload config |
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioLowerVolume` | Volume down |
| `XF86AudioMute` | Mute |
| `XF86MonBrightnessUp` | Brightness up |
| `XF86MonBrightnessDown` | Brightness down |
| `XF86AudioPlay` | Play/pause |
| `XF86AudioNext` | Next track |
| `XF86AudioPrev` | Previous track |

## Packages that may fail to install (script warns and skips)

AUR package names change over time. If the official repo version of `zed` doesn't suit you, use the AUR `zed-preview-bin`; `pycharm`/`rubymine` are AUR builds (downloading official tarballs), or you can install them manually via JetBrains Toolbox.

## File layout

```
.
├── install.sh          # main script (idempotent, supports --only)
├── packages/
│   ├── pacman.txt      # official repos (one package per line, # comments)
│   └── aur.txt         # AUR
├── assets/
│   ├── colin-watts.jpg # SDDM / desktop wallpaper
│   └── screenshot.png  # README cover image
└── dotfiles/           # mirrored onto ~ as-is (existing files are overwritten)
    ├── .zshrc
    ├── .pi/agent/      # pi-coding-agent config
    ├── .config/hypr/   # hyprland.lua + hyprlock + hypridle + hyprpaper
    ├── .config/waybar/ # waybar modules
    ├── .config/kitty/  # includes catppuccin mocha theme
    ├── .config/rofi/ + .local/share/rofi/themes/
    ├── .config/dunst/  # includes mocha colors
    ├── .config/mpv/    # uosc/thumbfast/sponsorblock provided by AUR
    ├── .config/git/    # custom = delta + catppuccin (included by user-owned ~/.config/git/config)
    ├── .config/fcitx5/ # fcitx5 config (profile/classicui/rime.conf)
    ├── .local/share/fcitx5/rime/ # rime-ice default.custom.yaml
    ├── .config/atuin/  # includes catppuccin theme
    ├── .config/Kvantum/ # Qt theme (catppuccin-mocha-blue)
    ├── .config/gtk-3.0/ + .config/fontconfig/
    ├── .config/direnv/ # includes layout_uv
    ├── .config/nvim/   # LazyVim config (init.lua + lua/config + lua/plugins)
    ├── .config/satty/ + .config/zathura/ + .config/pcmanfm/
    ├── .config/zed/   # settings.json
    ├── .config/mimeapps.list + .config/user-dirs.{conf,dirs}
    ├── .local/share/applications/ # overrides system .desktop (deepseek/github/gmail/kimi/wechat etc.)
    ├── .local/share/icons/ # PWA icons (deepseek/github/gmail/kimi)
    └── .local/share/catppuccin_mocha-zsh-syntax-highlighting.zsh
```

## License

MIT, see [LICENSE](LICENSE).

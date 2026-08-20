[English](README.md) | [中文](README.zh.md)

![arch-config screenshot](assets/screenshot.png)

# arch-config — personal Arch Linux (Hyprland) system config

Personal Arch Linux + Hyprland bootstrap, managed by Ansible. One playbook
installs all packages and deploys every config file; theme is
catppuccin-mocha (blue accent).

The repo no longer uses `install.sh` — the playbook under `playbooks/` is the
single source of truth.

## Requirements

- Arch Linux (base install done, e.g. via archinstall — see "Base install" below)
- `ansible` package installed (`sudo pacman -S ansible`)
- sudo privileges (the playbook asks for the become password)

## Usage

```bash
git clone <your-repo> ~/arch-config
cd ~/arch-config/playbooks
ansible-playbook site.yml --ask-become-pass               # full setup
ansible-playbook site.yml --tags waybar --ask-become-pass  # one app only
ansible-playbook site.yml --list-tasks                     # what's available
```

Re-running is safe (idempotent). Each app has its own tag, named after the
app (e.g. `waybar`, `hyprland`, `zsh`, `nvim`).

## Layout

```
playbooks/
├── site.yml                    # entrypoint: roles base → software → settings → services
├── inventory/
│   ├── hosts.ini               # host alias "desktop" (connection=local)
│   ├── group_vars/all.yml      # shared vars (home, uid, timezone, themes, unit lists)
│   └── host_vars/desktop.yml   # machine vars: monitor, scale, net_interface
└── roles/
    ├── base/                   # timezone, locale, zram, sshd, groups, shell, xdg user-dirs
    ├── software/               # packages (_pacman.yml / _aur.yml) + one <app>.yml per app
    │   ├── files/<app>/        # static config files, one dir per app (28 apps)
    │   └── templates/<app>/    # hyprland.lua, waybar config, wechat desktop entry
    ├── settings/               # GTK/Qt/Kvantum/font configs, fcitx5 + SDDM themes, gsettings
    └── services/               # system systemd units + user pipewire/dsh-web units
```

The `software` role manages 28 apps (atuin, deepseek, dev, direnv, dsh-web,
dunst, fcitx5, git, github, gmail, hypridle, hyprland, hyprlock, hyprpaper,
kimi, kitty, mimeapps, mpv, nvim, pcmanfm, pi, rofi, satty, try-cli, waybar,
wechat, zathura, zed, zsh). All official-repo packages live in
`tasks/_pacman.yml`, all AUR packages in `tasks/_aur.yml`; per-app task files
only deploy configuration.

## Machine differences

Machine-specific values (monitor name, scale factor, network interface) live
in `playbooks/inventory/host_vars/desktop.yml` — edit them there, not in the
templates. Current values: monitor `DP-1` @ scale 1.25, NIC `wlp6s0`. To add
another machine, add a host alias to `inventory/hosts.ini` and a matching
`host_vars/<name>.yml`.

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

## Base install (archinstall suggestions)

- If you use btrfs, install `compsize` afterwards
- Mirrors: `reflector --country China --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist`
- The playbook sets the timezone to Asia/Shanghai and generates en_US.UTF-8 + zh_CN.UTF-8, default `LANG=zh_CN.UTF-8` (terminal errors stay in English via `LC_MESSAGES=en_US.UTF-8`)

## Manual steps after install

1. **Monitor**: check the interface name with `hyprctl monitors`, then edit `monitor`/`scale` in `playbooks/inventory/host_vars/desktop.yml` and re-run `ansible-playbook site.yml --tags hyprland` (the rendered `~/.config/hypr/hyprland.lua` is a template now; direct edits get overwritten). Default is `DP-1` + scale 1.25; external monitors usually use 1
2. **neovim**: config is deployed by the playbook (LazyVim); on first launch it auto-installs plugins and compiles tree-sitter grammars (needs gcc, already in the package list)
3. **Input method**: fcitx5 autostarts after re-login; rime auto-deploys rime-ice on first run. To keep your old word-frequency data, copy `~/.local/share/fcitx5/rime/*.userdb` from the old system
4. **dropbox**: `hl.exec_cmd("dropbox")` is commented out in hyprland.lua; uncomment it after installing the AUR package
5. **VirtualBox**: extension pack in AUR `virtualbox-ext-oracle`; if modules break after a kernel update, run `sudo vboxreload`
6. **goldendict-ng**: dictionaries must be placed manually, see the [Dictionaries](https://github.com/xiaoyifang/goldendict-ng?tab=readme-ov-file#dictionaries) docs (put dictionary files under `~/.local/share/goldendict`, then add the directory in settings). Autostarts in the tray at login; `Super+T` forwards the query through single-instance IPC, avoiding cold start
7. **git**: on the first run of the git app (only when `~/.config/git/config` is missing) the playbook asks for `user.name`/`user.email`, saved to `~/.config/git/config` — that file is yours and is never overwritten afterwards. Shared settings (delta, catppuccin theme) live in `~/.config/git/custom`, which is managed by the playbook; don't edit it

## dsh web (DeepSeek Harness)

`dsh web` serves the DeepSeek Harness coding-agent browser UI at <http://127.0.0.1:3080>. The playbook installs the CLI globally (`npm i -g @deepseek-ai/dsh`, lands in `~/.local/bin/dsh`); the `dsh-web` app deploys the user unit (`~/.config/systemd/user/dsh-web.service`) and the `services` role enables it, so it starts at login:

```bash
systemctl --user status dsh-web        # status
journalctl --user -u dsh-web -f        # follow logs
systemctl --user restart dsh-web       # restart
```

- **Port**: binds 127.0.0.1:3080 by default (`--host 0.0.0.0` is intentionally rejected). To change it, edit `ExecStart=... dsh web --port 8080` in `~/.config/systemd/user/dsh-web.service`, then `systemctl --user daemon-reload && systemctl --user restart dsh-web`
- **API keys**: put them in `~/.dsh/.env` (e.g. `DEEPSEEK_API_KEY=...`) — the launcher loads it automatically; keep secrets out of the unit file
- **Upgrade**: `npm i -g @deepseek-ai/dsh@latest && systemctl --user restart dsh-web`
- **npm ≥ 12** blocks install scripts by default, so `npm i -g` warns about koffi/node-pty/… — dsh still works (native prebuilds ship with the packages, or compile on demand). To run the scripts anyway: `npm i -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh`
- **Port already in use**: if an old `npx @deepseek-ai/dsh web` instance is still running, stop it first (`pkill -f "dsh web"`), then `systemctl --user reset-failed dsh-web && systemctl --user restart dsh-web`
- **Config-only deploys**: if you run only `--tags dsh-web`, the unit is deployed but not enabled — enable once manually: `systemctl --user enable --now dsh-web`

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

## License

MIT, see [LICENSE](LICENSE).

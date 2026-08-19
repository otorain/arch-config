# Ansible Migration Design

Date: 2026-08-19
Status: approved (awaiting spec review)

## Goal

Replace `install.sh` + `scripts/` + `packages/` + `dotfiles/` entirely with a
modular Ansible project under `playbooks/`. The current bash pipeline is a
single 369-line script with stage functions; the new architecture is organized
around four layers and per-application task files instead of mirroring the old
stages.

Non-goals: multi-distro support, remote hosts, secrets management (vault).

## Decisions (from brainstorming)

- Full replacement: `install.sh`, `scripts/*.sh`, `packages/*.txt`, and the
  `dotfiles/` tree are deleted once the playbook is verified on the real
  machine. Their content is absorbed into roles.
- Inventory is multi-machine ready but only one host (`desktop`) is defined
  now; machine differences (monitor, scale, NIC) live in `host_vars/`.
- AUR packages are installed by calling `yay` from tasks (probe `yay -Si`,
  warn-and-continue on failure), same semantics as today. No galaxy
  collection.
- Official-repo packages are installed once up front (`_pacman.yml`), not
  distributed per app. App task files only deploy config / user services /
  shell fragments.
- dotfiles follow their software: each app task file owns its static files,
  templates, and zsh fragments. There is no central dotfiles role.
- `.zshrc` is split: a skeleton plus numbered fragments in
  `~/.config/zsh/conf.d/`, each fragment owned by the app that needs it.
- Four roles named after the four layers: `base`, `software`, `settings`,
  `services`. The theming layer is `settings` (not `theme`, not `desktop`).

## Repository layout

```
playbooks/
├── ansible.cfg                 # inventory path, connection=local default, diff=True
│                               #   (run all ansible-playbook commands from playbooks/)
├── site.yml                    # single entrypoint: base → software → settings → services
├── inventory/
│   ├── hosts.ini               # [desktop] localhost ansible_connection=local
│   ├── group_vars/all.yml      # target_user, timezone, locale, theme accent
│   └── host_vars/desktop.yml   # monitor=DP-1, scale=1.25, net_interface=wlp6s0
└── roles/
    ├── base/                   # layer 1: basic system setup
    ├── software/               # layer 2: per-application install/config/services
    ├── settings/               # layer 3: fonts + theming + gsettings + SDDM
    └── services/               # layer 4: system systemd units + user pipewire
```

Kept as-is: `assets/`, `docs/`, `README.md`, `README.zh.md` (both READMEs get
rewritten at the end; AGENTS.md too).

## Role responsibilities

| role | contents (mapped from old stages) |
|------|-----------------------------------|
| `base` | preflight assertions (`/etc/arch-release`, non-root, network), timezone `Asia/Shanghai`, locale.gen (en_US + zh_CN) + locale.conf (LANG=zh_CN, LC_MESSAGES=en_US), zram-generator.conf, sshd `PermitRootLogin no`, user groups (wheel,docker,vboxusers,libvirt), default shell → zsh |
| `software` | all packages + all per-app config + user-level services (structure below) |
| `settings` | font packages stay in `_pacman.yml`; this role does: fcitx5 catppuccin theme (absorbs `install-fcitx5-theme.sh`), GTK4/Libadwaita symlinks (assets, gtk.css, gtk-dark.css → Colloid), gsettings (gtk-theme, icon-theme, color-scheme, font-name; warn-only without session bus), fc-cache |
| `services` | system units: NetworkManager, bluetooth, sshd, fail2ban, cups.socket, avahi-daemon, udisks2, earlyoom, fstrim.timer, docker.socket, libvirtd.socket, sddm (enable --now, warn on failure); user units: pipewire, pipewire-pulse, wireplumber; dsh-web user service enable (from old post stage) |

SDDM theme + wallpaper deployment (theme dir detection, `theme.conf`
Background rewrite, `/etc/sddm.conf.d/10-theme.conf`) lives in `settings`
since it is theming; enabling the `sddm` unit lives in `services`.

## software role structure

```
roles/software/
├── tasks/main.yml              # include_tasks in fixed order, each with tags
├── tasks/apps/
│   ├── _pacman.yml             # ALL official-repo packages in one
│   │                           #   community.general.pacman task; list keeps
│   │                           #   the per-application comment groups from
│   │                           #   packages/pacman.txt
│   ├── yay.yml                 # yay bootstrap (absorbs scripts/install-yay.sh)
│   ├── _aur.yml                # ALL AUR packages: yay -Si probe per package,
│   │                           #   warn-and-continue on failure (aur.txt)
│   ├── zsh.yml                 # oh-my-zsh (absorbs install-oh-my-zsh.sh),
│   │                           #   .zshrc skeleton, conf.d dir, own fragments
│   ├── cli-tools.yml           # zsh fragments for small CLIs
│   ├── kitty.yml               # kitty.conf + zsh fragment
│   ├── nvim.yml                # LazyVim starter tree + lazy-lock.json
│   ├── git.yml                 # ~/.config/git/custom (delta+catppuccin) and
│   │                           #   one-time identity creation via vars_prompt
│   ├── mpv.yml                 # mpv config + symlink /usr/share/mpv/scripts/*
│   ├── fcitx5.yml              # fcitx5 conf + rime-ice data + profile
│   ├── hyprland.yml            # hyprland.lua (template) + hyprpaper/idle/lock
│   │                           #   configs + wallpaper.jpg
│   ├── waybar.yml              # config.jsonc + style.css (templates) +
│   │                           #   weather.py / calendar.py / waybar_geom.py
│   ├── web-apps.yml            # 4 Chrome web apps: deepseek, github, gmail,
│   │                           #   kimi (.desktop + hicolor icons)
│   ├── gui-apps.yml            # native GUI app overrides; currently only
│   │                           #   wechat.desktop.j2 (QT_SCALE_FACTOR=scale)
│   └── dev.yml                 # npm prefix + global tools, rustup default,
│                               #   try-cli (absorbs install-try-cli.sh),
│                               #   xdg-user-dirs, ~/Projects etc, bat cache
├── files/apps/<app>/…          # static dotfiles per app
├── templates/apps/<app>/…      # hyprland.lua, waybar config, wechat.desktop
└── handlers/main.yml           # reload waybar (SIGUSR2), update-desktop-db,
                                #   gtk-update-icon-cache, fc-cache
```

### Ordering constraints (hard)

`_pacman.yml → yay.yml → _aur.yml` must run first, in this order:

- `yay.yml` compiles yay and needs `base-devel` + `git` from `_pacman.yml`.
- `_aur.yml` needs the `yay` binary.
- `web-apps.yml` needs `google-chrome` (AUR), `gui-apps.yml` needs
  `wechat-bin` (AUR) — both satisfied by being after the underscore files.

Underscore prefix marks "order-sensitive infrastructure, not an app". All
other app files may be ordered freely; `main.yml` lists them alphabetically
after the three underscore files.

### Tags

Every include gets a tag equal to the app name; the three infrastructure
files get `packages`, `yay`, `aur` respectively. Partial runs:
`ansible-playbook site.yml --tags waybar`. Role-level tags (`base`,
`software`, `settings`, `services`) apply to whole layers.

## .zshrc modularization

Skeleton `.zshrc` (deployed by `zsh.yml`) keeps only: env vars (EDITOR,
DIRENV_LOG_FORMAT, PATH with pnpm + ~/.local/bin), oh-my-zsh bootstrap,
history options, generic aliases (`open=xdg-open`), and:

```zsh
for f in ~/.config/zsh/conf.d/*.zsh(N); do source "$f"; done
```

Fragments (numeric prefix = load order, owned by the named app):

| fragment | owner | contents |
|----------|-------|----------|
| `20-zoxide.zsh` | cli-tools | `zoxide init` |
| `30-fzf.zsh` | cli-tools | `fzf --zsh` (zle-guarded) |
| `40-kitty.zsh` | kitty | kitty shell integration |
| `50-yazi.zsh` | cli-tools | `y()` cwd-on-exit function |
| `60-try.zsh` | dev | `try init ~/src/tries` |
| `70-direnv.zsh` | cli-tools | `direnv hook` |
| `80-atuin.zsh` | cli-tools | `atuin init --disable-up-arrow` (zle-guarded) |
| `90-catppuccin-highlight.zsh` | zsh | catppuccin syntax-highlight colors |
| `99-syntax-highlighting.zsh` | zsh | must be last (existing constraint) |

App-local aliases live in the owning app's fragment: `lg=lazygit` →
cli-tools, `zed=zeditor` → dev. Removing an app removes its packages from
the list, its fragment, and its config in one place.

## Privilege & execution model

- Playbook runs as the target user (connection local); tasks that need root
  use `become: true`. Entry: `ansible-playbook site.yml --ask-become-pass`.
  This replaces the `as_user`/`as_user_home`/`sudo` switching in install.sh.
- User-session operations that need a bus/runtime dir (systemctl --user,
  gsettings) set `XDG_RUNTIME_DIR=/run/user/<uid>` / DBUS address via role
  vars, mirroring the current guessed-bus behavior; failures warn, not fail.

## Idempotency

- pacman: `community.general.pacman` with the full name list.
- yay installs: `command`/`ansible.builtin.command` guarded by
  `yay -Qi <pkg>` register checks (or `creates:` where a sentinel path
  exists); the bootstrap clone uses the `git` module.
- All config files: `copy`/`template` — changes trigger handlers only.
- git identity: `~/.config/git/config` created once via `vars_prompt`
  (only when missing, `stat` check), never overwritten; warns if the
  `config/git/custom` include is absent. Same semantics as today.
- mpv scripts: `file state=link` loop over `/usr/share/mpv/scripts/*`.

## Machine differences (templates)

`host_vars/desktop.yml` holds `monitor: DP-1`, `scale: 1.25`,
`net_interface: wlp6s0`, `timezone` stays global. Consumed by:

- `hyprland.lua.j2` — `hl.monitor` line (the commented DP-2/eDP-1 alternates
  in the current file are replaced by the variable)
- `config.jsonc.j2` — waybar `network.interface`
- `wechat.desktop.j2` — `QT_SCALE_FACTOR={{ scale }}` (same parameter as the
  Hyprland scale; one variable, two consumers)

A future laptop adds `host_vars/laptop.yml` and one hosts.ini line; no role
changes.

## Verification

Replaces `shellcheck install.sh` + `luac -p hyprland.lua`:

- `ansible-playbook site.yml --syntax-check`
- `ansible-playbook site.yml --check --diff` (dry-run preview)
- `ansible-lint` (add to packages)
- `luac -p` still applies to the hyprland.lua **template output**; run it
  against a rendered copy during development, not against the .j2.

## Migration strategy

1. Scaffold `playbooks/` (cfg, inventory, site.yml, empty roles).
2. Implement roles bottom-up in order: `base` → `software` infrastructure
   (_pacman/yay/_aur) → `software` apps (one file at a time) → `settings` →
   `services`.
3. After each app file: verify on the real machine with
   `ansible-playbook site.yml --tags <app>` (idempotent, safe to re-run).
   NOTE: unlike install.sh (which was never run on the working machine), the
   playbook is designed to be run here — it replaces the old script's job of
   keeping this machine in sync.
4. When all tags verified: delete `install.sh`, `scripts/`, `packages/`,
   `dotfiles/`; rewrite AGENTS.md (layout/verification/gotchas) and both
   READMEs (keep dual-language, English + Chinese mirror in sync).

## Gotchas carried over (must not regress)

- hyprland.lua stays Lua (Hyprland 0.55+); do not generate a hyprland.conf.
- hypridle dpms commands use the Lua DSL (`hl.dsp.dpms`); waybar workspace
  click is a known waybar 0.15 bug — do not "fix" via config.
- weather.py / calendar.py popups keep their LD_PRELOAD gtk4-layer-shell
  re-exec block and `PRIORITY_USER` CSS; no Hyprland window_rule for them.
- gtk-layer-shell (GTK3) stays in the package list (waybar links it).
- ~/.config/git/config is user-owned: create once, never overwrite.
- Everything themes catppuccin-mocha (blue accent); UI text in dotfiles
  stays Chinese; comments/docs/playbook output in English.
- `~/.local/bin/try` wraps the tobi/try git clone, not the AUR `try` package.
- The gsettings/dbus steps may warn-and-continue on headless runs — expected.
- Do not run stylua on hyprland.lua (or its template): 4-space indent,
  aligned `=`.

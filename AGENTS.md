# AGENTS.md

Personal Arch Linux + Hyprland bootstrap, managed by Ansible. Not an
application: no build, no automated tests, no git history. Docs and code
comments are in English. Commit messages are in English.

## Verification

- `cd playbooks && ansible-playbook site.yml --syntax-check` and `ansible-lint`
  are the static checks; `luac -p` applies to the **rendered**
  `~/.config/hypr/hyprland.lua`, not the `.j2` template.
- Do NOT run stylua on `hyprland.lua.j2` — default stylua (tabs) would
  reformat the whole file; existing style is 4-space indent with aligned `=`.
- The playbook is designed to run on this machine:
  `cd playbooks && ansible-playbook site.yml --ask-become-pass`, or a subset
  via `--tags <app>` (e.g. `--tags waybar`). NEVER copy files from
  `playbooks/roles/**/files/` into `$HOME` by hand — deploy via the playbook.

## Layout

- `playbooks/` — the whole Ansible project. Run all ansible commands from here.
  - `site.yml` — single entrypoint, runs roles `base → software → settings → services`.
  - `inventory/hosts.ini` — host alias `desktop` (connection=local); add future
    machines here plus a matching `host_vars/<name>.yml`.
  - `inventory/group_vars/all.yml` — shared vars (home, uid, timezone, theme
    names, npm globals, systemd unit lists).
  - `inventory/host_vars/desktop.yml` — machine vars: `monitor`, `scale`,
    `net_interface`. Consumed by the hyprland.lua / waybar / wechat templates.
  - `roles/base` — layer 1: preflight asserts, timezone, locale, zram, sshd
    hardening, user groups, default shell. Its `files/` holds
    `user-dirs.conf` / `user-dirs.dirs` (deployed to `~/.config/`) and it runs
    `xdg-user-dirs-update`.
  - `roles/software` — layer 2: packages + per-app config. `tasks/` is flat
    (no subdirs): `main.yml` includes the infra files `_pacman.yml → yay.yml →
    _aur.yml` FIRST (hard order constraint: yay needs base-devel+git, _aur
    needs yay; `_aur_one.yml` is a per-package helper), then one `<app>.yml`
    per application, each tagged with the app name. Includes use the
    `include_tasks` + module-arg `apply: tags:` + outer `tags:` pattern
    (plain `tags:` on a dynamic include does not reach inner tasks).
    All official packages live in `_pacman.yml`, all AUR packages in
    `_aur.yml` (warn-and-continue per package); app files only deploy config,
    user services, and zsh fragments.
    - `files/` has one directory **per software** (29 apps): atuin, deepseek,
      dev, direnv, dsh-web, dunst, fcitx5, git, github, gmail, hypridle,
      hyprland, hyprlock, hyprpaper, kimi, kitty, mimeapps, mpv, nvim,
      pcmanfm, pi, rofi, satty, try-cli, waybar, wechat, zathura, zed, zsh.
      Each contains only files — no subdirectories mirroring destination
      paths, no hidden structural names; destinations appear only in task
      `dest:` (dev and hyprland have no files dir; wechat is template-only).
      Exception: `files/nvim/` keeps its internal tree (deployed wholesale).
      Deleting a software = delete `files/<sw>/` + `tasks/<sw>.yml` + one
      include line in `main.yml`.
    - `templates/<software>/` — hyprland/hyprland.lua.j2,
      waybar/config.jsonc.j2, wechat/wechat.desktop.j2.
  - `roles/settings` — layer 3: fcitx5 catppuccin theme, GTK/Qt/Kvantum/font
    config files, GTK4 Colloid symlinks, gsettings, SDDM theme + wallpaper.
    Its `files/` are flat with collision-avoiding prefixes:
    `gtk3-settings.ini`, `gtk4-settings.ini`, `gtkrc-2.0`, `kvantum.kvconfig`,
    `catppuccin-mocha-blue.kvconfig`, `catppuccin-mocha-blue.svg`,
    `fonts.conf`.
  - `roles/services` — layer 4: system systemd units + user pipewire units +
    dsh-web user service.
- `assets/colin-watts.jpg` — one wallpaper used twice: SDDM theme background
  and `~/.config/hypr/wallpaper.jpg` (referenced by `hyprpaper.conf`).
- README is dual-language: `README.md` English (GitHub homepage),
  `README.zh.md` Chinese mirror. Keep both in sync.

## Gotchas

- Hyprland config is **Lua** — Hyprland 0.55+ dropped hyprlang. Do not create
  or edit a `hyprland.conf`.
- Hyprland 0.55+ rejects legacy `hyprctl dispatch <name> <args>` strings; use
  the Lua DSL (`hl.dsp.dpms({ action = "disable" })`). Known casualties: dpms
  in `hypridle.conf`, and waybar 0.15.0's `hyprland/workspaces`
  click-to-switch (fixed in waybar master; resolves with the 0.16 release —
  don't "fix" it via config or by switching to waybar-git unless asked).
- The weather popup (`weather.py --popup`) and clock popup (`calendar.py`)
  are fullscreen transparent **gtk4-layer-shell** surfaces — position, CSS
  rounded corners, and click-outside-to-close live inside the scripts. Do not
  add Hyprland window_rules for them, do not reintroduce focus-out dismissal,
  and do not remove the `LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so` re-exec
  block (gtk4-layer-shell must load before libwayland-client). App CSS that
  must override the Colloid theme needs `Gtk.STYLE_PROVIDER_PRIORITY_USER`
  (theme loads at USER priority 800). Both popups anchor under their waybar
  module via AT-SPI geometry through `waybar_geom.py`.
- Machine differences live in `host_vars/` — monitor `DP-1` @ scale 1.25,
  waybar `network.interface = wlp6s0`, wechat `QT_SCALE_FACTOR`. Don't
  hardcode them back into templates.
- `~/.config/git/config` is user-owned — created once (interactive
  user.name/user.email prompt on first run), never overwritten; it includes
  the managed `~/.config/git/custom` (delta + catppuccin).
- gsettings over a guessed `DBUS_SESSION_BUS_ADDRESS` can fail on a
  headless/tty run and only warns; that's expected.
- `~/.local/bin/try` wraps a git clone of `tobi/try` (Ruby). The AUR package
  named `try` is a different tool — don't swap it in.
- Everything themes to catppuccin-mocha (blue accent). New config should match.
- User-facing UI text stays Chinese (desktop entry names/comments, waybar
  labels, hyprlock placeholder). Everything else — comments, docs, playbook
  task names and output — is English.
- `.zshrc` is a skeleton sourcing `~/.config/zsh/conf.d/*.zsh` in lexical
  order. ALL 13 fragments live in `roles/software/files/zsh/` root (numbered
  05–99) and are deployed via `with_fileglob: "zsh/[0-9]*.zsh"` to
  `~/.config/zsh/conf.d/`; `99-syntax-highlighting.zsh` must stay last.
  `~/.zshrc` itself is deployed ONCE (`force: false`) — the user owns it
  afterwards; a grep+warn pair warns when an existing `.zshrc` lacks the
  conf.d sourcing loop.

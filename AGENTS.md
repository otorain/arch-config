# AGENTS.md

Personal Arch Linux + Hyprland bootstrap. Not an application: no build, no automated tests, no git history. Docs and code comments are in English. Commit messages are in English.

## Verification

- `shellcheck install.sh` and `luac -p dotfiles/.config/hypr/hyprland.lua` are the only static checks (tools are in `packages/pacman.txt`).
- Do NOT run `stylua` on `hyprland.lua` — default stylua (tabs) would reformat the whole file; existing style is 4-space indent with aligned `=`.
- NEVER run `./install.sh` on the machine you're working on — it mutates system state (pacman, systemd, `/etc`, `$HOME`). It only runs on Arch, as a non-root user with sudo.
- NEVER copy dotfiles directly into `$HOME` or edit live config files under `~/.config` to "apply" a change — the running system is only updated via `install.sh` (e.g. `./install.sh --only dotfiles`). Edit the file under `dotfiles/` (or the relevant source), then deploy with install.sh.

## Layout

- `install.sh` — single entrypoint, idempotent stages: `preflight → pacman → yay → aur → system → services → user → dotfiles → themes → mpv → post`. `--only stage1,stage2` runs a subset. Adding a stage means touching 3 places: the function, `main()`, and the header comment.
- `packages/{pacman,aur}.txt` — one package per line, `#` comments. The AUR stage probes `yay -Si` and skips missing packages with a warning instead of failing.
- `dotfiles/` — mirrored 1:1 onto `$HOME` (including dotfiles, via `find . -type f`); pre-existing files are overwritten without backup. Adding a file here = deployed to `~`.
- `dotfiles/.config/nvim/` — LazyVim starter structure: `lua/config/` holds global config, `lua/plugins/` one plugin spec per file. Plugin bodies are not committed to dotfiles; lazy.nvim pulls them on first launch; `lazy-lock.json` must be updated along with config.
- `assets/colin-watts.jpg` — one wallpaper used twice: SDDM theme background and `~/.config/hypr/wallpaper.jpg` (referenced by `hyprpaper.conf`).
- README is dual-language: `README.md` English (GitHub homepage), `README.zh.md` Chinese mirror. Keep both in sync; do not translate the zh mirror away.

## Gotchas

- Hyprland config is **Lua** (`dotfiles/.config/hypr/hyprland.lua`) — Hyprland 0.55+ dropped hyprlang. Do not create or edit a `hyprland.conf`.
- The dpms command in `hypridle.conf` must use the Lua DSL form; the old syntax `hyprctl dispatch dpms off` throws a Lua parse error on 0.55+ (symptom: locks but never blanks the screen). Correct form: `hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'` (`enable` likewise).
- Machine-specific hardcodes are intentional, don't "fix" them: monitor `DP-1` @ scale 1.25 (real-machine alternates `DP-2`/`eDP-1` are commented in the file), waybar `network.interface = "wlp6s0"` (laptop variant `wlo1` noted in comment), timezone `Asia/Shanghai`.
- `install.sh` supports both `./install.sh` and `sudo ./install.sh` via `TARGET_USER="${SUDO_USER:-$USER}"` and the `as_user`/`as_user_home` helpers. Any stage that writes under `$TARGET_HOME` must use these helpers (and chown afterwards), or files end up root-owned.
- The `themes` stage calls `gsettings` over a guessed `DBUS_SESSION_BUS_ADDRESS` — it can fail on a headless/tty run and only warns; that's expected.
- `~/.local/bin/try` wraps a git clone of `tobi/try` (Ruby). The AUR package named `try` is a different tool — don't swap it in.
- Everything themes to catppuccin-mocha (blue accent): kitty, rofi, dunst, waybar, GTK (Colloid-Dark-Catppuccin), Qt (kvantum), cursors, SDDM, git-delta, zsh syntax highlighting. New config should match.
- User-facing UI text stays Chinese (desktop entry names/comments, waybar labels, hyprlock placeholder). Everything else — comments, docs, and install.sh output strings (info/ok/warn/die/echo messages) — is English.

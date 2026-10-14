# Add GoLand (JetBrains Go IDE) — Design

**Date:** 2026-10-14

## Problem

GoLand, the JetBrains Go IDE, is not managed: no entry in `_aur.yml`, no
keybinding. PyCharm and RubyMine (its JetBrains siblings) are AUR packages in
the `# === JetBrains IDE ===` group plus a Hyprland keybinding each.

## Choices (confirmed with user)

- **Source:** AUR `goland` — same maintainer (freswa) and packaging as the
  installed `pycharm`/`rubymine`; ships `/usr/bin/goland` and its own
  `jetbrains-goland.desktop`.
- **Runtime:** system JRE (`jre-openjdk`, official repos) over the AUR
  `goland-jre` subpackage. The `goland` PKGBUILD deletes the bundled `jbr/`
  directory and lists `goland-jre` / `java-runtime` as optional deps, so a
  system JRE is required for launch. `jre-openjdk` installs before AUR
  packages (`_pacman.yml` precedes `_aur.yml` in `main.yml`), so
  `java-runtime` is satisfied when `goland` installs. Known trade-off,
  accepted by the user after confirming: JetBrains documents JBR 21 as the
  bundled/validated runtime and states JRE/JDK-modified installs are not
  supported (JCEF and the new UI are built against JBR); `jre-openjdk` is
  currently Java 27. If GoLand misbehaves, switch to `goland-jre`.
- **Scope:** match PyCharm/RubyMine — package + Hyprland keybinding + README /
  usage doc updates. No app task file, no config deployment, no desktop entry
  (the package ships one), no `docs/apps.md` section (siblings have none).
- **Keybinding:** `Super+Ctrl+G` (free; mnemonic Go).

## Design

1. `playbooks/roles/software/tasks/_pacman.yml` — add to the
   `# === Programming languages ===` group:

   ```yaml
   - jre-openjdk
   ```

2. `playbooks/roles/software/tasks/_aur.yml` — add to the
   `# === JetBrains IDE ===` group:

   ```yaml
   - goland
   ```

3. `playbooks/roles/software/templates/hyprland/hyprland.lua.j2` — after the
   pycharm binding (line 178):

   ```lua
   hl.bind(mod .. " + CTRL + G", hl.dsp.exec_cmd("goland"))
   ```

4. `README.md` / `README.zh.md` — keybinding table gains
   `| Super+Ctrl+G | GoLand |` after the PyCharm row; the troubleshooting
   note "`pycharm`/`rubymine` are AUR builds" becomes
   "`pycharm`/`rubymine`/`goland` are AUR builds".

5. `docs/usage.md` — shortcut row becomes
   `` | `Super+Ctrl+R` / `+P` / `+G` | RubyMine / PyCharm / GoLand | ``.

## Out of scope

- GoLand license activation and per-user IDE config (`~/.config/JetBrains/`
  is user data, never committed).
- JetBrains Toolbox.
- `goland-jre`; revisit only if the system JRE proves incompatible.

## Verification

- `cd playbooks && ansible-playbook site.yml --syntax-check` and `ansible-lint`.
- `luac -p` on the rendered `~/.config/hypr/hyprland.lua` after a
  `--tags hyprland` deploy.
- Actual install via `--tags packages,aur` (~1.5 GB download) — user's call.

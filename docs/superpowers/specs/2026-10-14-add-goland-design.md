# Add GoLand (JetBrains Go IDE) — Design

**Date:** 2026-10-14

## Problem

GoLand, the JetBrains Go IDE, is not managed: no entry in `_aur.yml`, no
keybinding. PyCharm and RubyMine (its JetBrains siblings) are AUR packages in
the `# === JetBrains IDE ===` group plus a Hyprland keybinding each.

## Choices (confirmed with user)

- **Source:** AUR `goland` (maintainer freswa); ships `/usr/bin/goland` and
  its own `jetbrains-goland.desktop`. The installed `pycharm`/`rubymine` are
  other maintainers' packages that bundle their JBR; `goland` alone strips it
  (see Runtime).
- **Runtime:** AUR `goland-jre` subpackage. The `goland` PKGBUILD strips the
  bundled `jbr/` and lists `goland-jre` / `java-runtime` as optional deps;
  the 2026.2 xplat launcher resolves a runtime only via product env var /
  user config file / bundled `jbr/` / `JDK_HOME` / `JAVA_HOME` (no PATH
  `java` fallback), and JetBrains supports only the bundled JBR — so the
  split `goland-jre` subpackage is installed alongside.
- **Scope:** match PyCharm/RubyMine — package + Hyprland keybinding + README /
  usage doc updates. No app task file, no config deployment, no desktop entry
  (the package ships one), no `docs/apps.md` section (siblings have none).
- **Keybinding:** `Super+Ctrl+G` (free; mnemonic Go).

## Design

1. `playbooks/roles/software/tasks/_aur.yml` — add to the
   `# === JetBrains IDE ===` group:

   ```yaml
   - goland
   - goland-jre
   ```

2. `playbooks/roles/software/templates/hyprland/hyprland.lua.j2` — after the
   pycharm binding (line 178):

   ```lua
   hl.bind(mod .. " + CTRL + G", hl.dsp.exec_cmd("goland"))
   ```

3. `README.md` / `README.zh.md` — keybinding table gains
   `| Super+Ctrl+G | GoLand |` after the PyCharm row; the troubleshooting
   note "`pycharm`/`rubymine` are AUR builds" becomes
   "`pycharm`/`rubymine`/`goland` are AUR builds".

4. `docs/usage.md` — shortcut row becomes
   `` | `Super+Ctrl+R` / `+P` / `+G` | RubyMine / PyCharm / GoLand | ``.

## Out of scope

- GoLand license activation and per-user IDE config (`~/.config/JetBrains/`
  is user data, never committed).
- JetBrains Toolbox.
- System JRE (`jre-openjdk`); the bundled `goland-jre` is used instead
  (see Runtime).

## Verification

- `cd playbooks && ansible-playbook site.yml --syntax-check` and `ansible-lint`.
- `luac -p` on the rendered `~/.config/hypr/hyprland.lua` after a
  `--tags hyprland` deploy.
- Actual install via `--tags aur`; launch check: `goland` opens (first-run
  license dialog).

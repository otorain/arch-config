# Add GoLand (JetBrains Go IDE) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Manage the JetBrains Go IDE (GoLand) as an AUR package with a system JRE, a Hyprland keybinding, and synced docs — matching the existing PyCharm/RubyMine treatment.

**Architecture:** GoLand is declared in the `software` role's flat package lists: `jre-openjdk` (official repos) in `_pacman.yml`, `goland` (AUR) in `_aur.yml`'s JetBrains group. No app task file, config deployment, or desktop entry (the AUR package ships `/usr/bin/goland` and `jetbrains-goland.desktop`). A new `Super+Ctrl+G` binding in the Hyprland Lua template launches it; the three keybinding/troubleshooting doc spots gain GoLand rows.

**Tech Stack:** Ansible (roles `software`), pacman/yay, Hyprland Lua config (0.55+), Markdown docs.

**Spec:** `docs/superpowers/specs/2026-10-14-add-goland-design.md`

## Global Constraints

- Package names are exactly `goland` (AUR) and `jre-openjdk` (official repos). Do NOT add `goland-jre` — the user explicitly chose the system JRE (Java 27) despite JetBrains not supporting JRE/JDK-modified installs; see spec.
- Keybinding is exactly `hl.bind(mod .. " + CTRL + G", hl.dsp.exec_cmd("goland"))` — Super+Ctrl+G is unused.
- No `tasks/goland.yml`, no `files/goland/`, no `main.yml` include (PyCharm/RubyMine have none).
- Run ALL ansible commands from `playbooks/`. NEVER copy files into `$HOME` by hand — deploy via the playbook.
- Comments: English, terse, current-state only, directly above the line they document; no trailing comments.
- Docs: `README.md` is English, `README.zh.md` and `docs/usage.md` are Chinese — keep user-facing UI text Chinese. Commits in English.
- Do not touch the unrelated modified `playbooks/roles/software/files/pyprland/config.toml` in the working tree.

---

### Task 1: Declare packages (`jre-openjdk` + `goland`)

**Files:**
- Modify: `playbooks/roles/software/tasks/_pacman.yml` (append inside the `# === Programming languages ===` group, after `- mise` at line 125)
- Modify: `playbooks/roles/software/tasks/_aur.yml` (append inside the `# === JetBrains IDE ===` group, after `- rubymine` at line 36)

**Interfaces:**
- Consumes: nothing.
- Produces: installed runtime + IDE that Tasks 2 and 4 rely on (`/usr/bin/goland`, `java-runtime` provided by `jre-openjdk`).

- [ ] **Step 1: Add the system JRE to `_pacman.yml`**

In `playbooks/roles/software/tasks/_pacman.yml`, the group currently ends:

```yaml
      - go
      - mise
      # === CLI tools ===
```

Change it to:

```yaml
      - go
      - mise
      - jre-openjdk
      # === CLI tools ===
```

(The comment convention is for non-obvious rationale only; an extra comment is not needed — the spec records why.)

- [ ] **Step 2: Add `goland` to `_aur.yml`**

In `playbooks/roles/software/tasks/_aur.yml`, the group currently reads:

```yaml
    # === JetBrains IDE ===
    - pycharm
    - rubymine
    # === Messaging ===
```

Change it to:

```yaml
    # === JetBrains IDE ===
    - pycharm
    - rubymine
    - goland
    # === Messaging ===
```

- [ ] **Step 3: Verify static checks pass**

Run (from `playbooks/`):

```bash
ansible-playbook site.yml --syntax-check && ansible-lint
```

Expected: syntax check prints `playbook: site.yml` and exits 0; ansible-lint reports no failures (pre-existing warnings, if any, unchanged).

- [ ] **Step 4: Verify package entries are visible to the tag/file that installs them**

Run (from `playbooks/`):

```bash
ansible-playbook site.yml --list-tasks --tags packages 2>/dev/null | rg -c "Packages \(official repos\)"
ansible-playbook site.yml --list-tasks --tags aur 2>/dev/null | rg -c "Packages \(AUR\)"
rg -n "goland" roles/software/tasks/_aur.yml && rg -n "jre-openjdk" roles/software/tasks/_pacman.yml
```

Expected: both counts are `1` (`--list-tasks` lists include names, not inner tasks); `goland` matches `_aur.yml` once; `jre-openjdk` matches `_pacman.yml` once.

- [ ] **Step 5: Commit**

```bash
git add playbooks/roles/software/tasks/_pacman.yml playbooks/roles/software/tasks/_aur.yml
git commit -m "goland: add AUR package and system JRE"
```

---

### Task 2: Hyprland keybinding

**Files:**
- Modify: `playbooks/roles/software/templates/hyprland/hyprland.lua.j2` (after the pycharm binding, line 178)

**Interfaces:**
- Consumes: `/usr/bin/goland` from Task 1 (binding only references the command name).
- Produces: `Super+Ctrl+G` → `goland`, verified on the rendered `~/.config/hypr/hyprland.lua`.

- [ ] **Step 1: Add the binding**

The bindings block currently reads:

```lua
hl.bind(mod .. " + CTRL + R", hl.dsp.exec_cmd("rubymine"))
hl.bind(mod .. " + CTRL + P", hl.dsp.exec_cmd("pycharm"))
hl.bind(mod .. " + F3", hl.dsp.exec_cmd("pcmanfm"))
```

Change it to:

```lua
hl.bind(mod .. " + CTRL + R", hl.dsp.exec_cmd("rubymine"))
hl.bind(mod .. " + CTRL + P", hl.dsp.exec_cmd("pycharm"))
hl.bind(mod .. " + CTRL + G", hl.dsp.exec_cmd("goland"))
hl.bind(mod .. " + F3", hl.dsp.exec_cmd("pcmanfm"))
```

Do NOT run stylua on this template (tabs would reformat the whole file).

- [ ] **Step 2: Deploy the rendered config**

Run (from `playbooks/`):

```bash
ansible-playbook site.yml --tags hyprland --ask-become-pass
```

Expected: `Deploy hyprland.lua (rendered from host_vars)` reports `changed`.

- [ ] **Step 3: Verify the rendered file**

```bash
luac -p ~/.config/hypr/hyprland.lua && echo SYNTAX-OK
rg -n 'CTRL \+ G' ~/.config/hypr/hyprland.lua
hyprctl configerrors
```

Expected: `SYNTAX-OK`; the rg match shows exactly `hl.bind(mod .. " + CTRL + G", hl.dsp.exec_cmd("goland"))`; `hyprctl configerrors` prints nothing (no config errors). Hyprland watches the file and reloads automatically.

- [ ] **Step 4: Commit**

```bash
git add playbooks/roles/software/templates/hyprland/hyprland.lua.j2
git commit -m "goland: add Super+Ctrl+G keybinding"
```

---

### Task 3: Docs sync (README.md, README.zh.md, docs/usage.md)

**Files:**
- Modify: `README.md` (keybinding table after line 211; troubleshooting line 265)
- Modify: `README.zh.md` (keybinding table after line 198; troubleshooting line 251)
- Modify: `docs/usage.md` (shortcut table line 17)

**Interfaces:**
- Consumes: keybinding from Task 2 (docs must show `Super+Ctrl+G`).
- Produces: no code interface; consistency between docs sets.

- [ ] **Step 1: README.md keybinding table**

After the row `| `Super+Ctrl+P` | PyCharm |` add:

```markdown
| `Super+Ctrl+G` | GoLand |
```

- [ ] **Step 2: README.md troubleshooting**

The sentence currently reads:

```markdown
  `zed-preview-bin`; `pycharm`/`rubymine` are AUR builds (they download the
```

Change to:

```markdown
  `zed-preview-bin`; `pycharm`/`rubymine`/`goland` are AUR builds (they download the
```

- [ ] **Step 3: README.zh.md keybinding table**

After the row `` | `Super+Ctrl+P` | PyCharm | `` add:

```markdown
| `Super+Ctrl+G` | GoLand |
```

- [ ] **Step 4: README.zh.md troubleshooting**

The sentence currently reads:

```markdown
  `zed-preview-bin`；`pycharm`/`rubymine` 是 AUR 构建（下载官方
```

Change to:

```markdown
  `zed-preview-bin`；`pycharm`/`rubymine`/`goland` 是 AUR 构建（下载官方
```

- [ ] **Step 5: docs/usage.md shortcut table**

The row currently reads:

```markdown
| `Super+Ctrl+R` / `+P` | RubyMine / PyCharm |
```

Change to:

```markdown
| `Super+Ctrl+R` / `+P` / `+G` | RubyMine / PyCharm / GoLand |
```

- [ ] **Step 6: Verify doc consistency**

Run from the repo root:

```bash
rg -n "GoLand|goland" README.md README.zh.md docs/usage.md
```

Expected: 5 matches —
`README.md` keybinding row + troubleshooting, `README.zh.md` keybinding row + troubleshooting, `docs/usage.md` row (`RubyMine / PyCharm / GoLand`) — and no other stray `goland` mentions. Both READMEs show `Super+Ctrl+G`.

- [ ] **Step 7: Commit**

```bash
git add README.md README.zh.md docs/usage.md
git commit -m "docs: add goland to keybinding tables and troubleshooting"
```

---

### Task 4: Real install on this machine (user-gated)

**Files:** none (system state only).

**Interfaces:**
- Consumes: Tasks 1–3 committed.
- Produces: installed `jre-openjdk` + `goland`; working `Super+Ctrl+G`.

- [ ] **Step 1: Confirm with the user before running**

This downloads ~1.5 GB (GoLand tarball) on top of a full `-Syu`, extracts
~3.5 GB to `/opt/goland`, and builds/installs via yay as `aur_builder`. Ask
the user for the go-ahead before running.

- [ ] **Step 2: Run the install**

Run (from `playbooks/`):

```bash
ansible-playbook site.yml --tags packages,aur --ask-become-pass
```

Expected: `Upgrade all system packages` and `Install official-repo packages`
report `changed` (full `-Syu` first — normal); `AUR: install: goland` reports
`changed`. If GoLand fails, the loop prints `install failed, handle manually:
goland` plus the stderr tail and the run continues — stop and investigate the
tail, then re-run.

- [ ] **Step 3: Verify packages installed**

```bash
pacman -Q jre-openjdk goland
rg '"version"' /opt/goland/product-info.json
ls -l /usr/bin/goland /usr/share/applications/jetbrains-goland.desktop
```

Expected: both packages print `name version`; product-info shows the 2026.2.x
version; `/usr/bin/goland` symlinks to `/opt/goland/bin/goland`; the desktop
entry exists.

- [ ] **Step 4: Manual acceptance**

Run `/usr/bin/goland` from a terminal (or press `Super+Ctrl+G`). Expected: the
startup log line shows the system JRE path (`/usr/lib/jvm/java-27-openjdk/...`,
not a bundled `jbr`), the GUI opens, and the first-run dialog asks for license
activation (expected — GoLand is commercial; activation is out of scope per
the spec).

## Self-Review Notes

- Spec coverage: runtime + package (Task 1), keybinding (Task 2), READMEs +
  usage doc (Task 3), install + verification (Task 4). Out-of-scope items
  (license activation, Toolbox, `goland-jre`, `~/.config/JetBrains`) are not
  implemented, per spec.
- No placeholders; all edits show exact before/after text.
- Naming consistent across tasks: package `goland`, binary `/usr/bin/goland`,
  binding `Super+Ctrl+G`, JRE `jre-openjdk`.

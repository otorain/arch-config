# Add Wine to Software List — Design

**Date:** 2026-09-02

## Problem

Wine is not in the software list: no entry in `_pacman.yml`, no app task.

## Choices (confirmed with user)

- **Variant:** `wine-staging` (official extra repo, `Provides: wine`) over
  plain `wine` or AUR `wine-cn`.
- **Companion:** `winetricks` (official extra repo).
- **Multilib:** NOT enabled. Arch switched official wine/wine-staging to the
  **new WoW64** mode since 10.8-2; most 32-bit Windows applications run
  without `[multilib]` or `lib32-*` packages. Revisit only if switching to
  AUR `wine32` / `wine-stable`.
- **Scope:** package-only group, no app task (matches precedents
  `rocm-smi-lib`, `engrampa`/`unrar`, `imagemagick`).

## Design

Append one group to `playbooks/roles/software/tasks/_pacman.yml` after
`=== Archive manager ===`:

```yaml
# === Wine ===
- wine-staging
- winetricks
- wine-gecko
- wine-mono
```

- `wine-gecko` / `wine-mono` are optional deps of wine-staging; managed via
  pacman as the Arch wiki recommends (avoids per-prefix downloads).
- No other changes: no `tasks/wine.yml`, no `main.yml` include, no
  `pacman.conf` edit, no `host_vars`.

## Out of scope

- Winetricks verbs and wine registry configuration (`~/.wine` is user data,
  never committed).
- Hyprland window rules for wine windows.
- Wine desktop entry generation (happens per-installed-program anyway).

# English Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert all docs and code comments in this repo to English.

**Architecture:** Mechanical translation across ~35 files. Comments (`#`, `//`, `--`, `/* */`, `<!-- -->`) become English; user-facing UI strings stay Chinese; `README.zh.md` stays Chinese; `AGENTS.md` is rewritten in English. Task groups are by directory area so each commit is a coherent unit.

**Tech Stack:** Plain text edits. No build, no tests. Static checks only: `shellcheck install.sh`, `luac -p dotfiles/.config/hypr/hyprland.lua`.

## Global Constraints

- Translate ONLY comments/docs. Never change configuration values, keys, or behavior.
- Keep user-facing UI text in Chinese: `.desktop` `Name`/`Comment` display strings, waybar format strings (离线/静音), hyprlock placeholder (输入密码…), rime display strings.
- Keep `README.zh.md` in Chinese (zh mirror). Keep the `[English](README.md) | [中文](README.zh.md)` switcher lines as-is in both READMEs.
- New and edited docs go in English.
- Do NOT run `stylua` on `hyprland.lua`. Existing 4-space indent style must be preserved.
- Do NOT run `./install.sh`.
- Commit messages in English, one commit per task group.

---

### Task 1: AGENTS.md rewrite (English)

**Files:**
- Modify: `AGENTS.md`

**Interfaces:**
- Produces: English conventions doc; says "Docs and code comments are in English", "README.zh.md stays Chinese", "user-facing UI text stays Chinese", "commit messages in English".

- [ ] **Step 1: Rewrite AGENTS.md fully in English**

Keep all existing sections (intro, Verification, Layout, Gotchas) and all technical facts (Lua DSL dpms syntax, machine-specific hardcodes, as_user helpers, `try` vs AUR `try`, catppuccin-mocha). Translate the Chinese parts; keep code/paths verbatim. New convention text:

```markdown
Personal Arch Linux + Hyprland bootstrap. Not an application: no build, no automated tests, no git history. Docs and code comments are in English. Commit messages are in English.
```

Add to Layout section:

```markdown
- README is dual-language: `README.md` English (GitHub homepage), `README.zh.md` Chinese mirror. Keep both in sync; do not translate the zh mirror away.
```

Gotchas to translate include: the `hypridle.conf` dpms Lua DSL note (symptom: locks but never blanks screen; correct form `hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'`), machine-specific hardcodes, `themes` stage gsettings warning, everything themes to catppuccin-mocha.

Add to Gotchas:

```markdown
- User-facing UI text stays Chinese (desktop entry names/comments, waybar labels, hyprlock placeholder). Only comments/docs are English.
```

- [ ] **Step 2: Verify no Chinese remains in AGENTS.md**

Run: `rg '[一-龥]' AGENTS.md`
Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs: rewrite AGENTS.md in English"
```

---

### Task 2: install.sh comments

**Files:**
- Modify: `install.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: English comments in install.sh (80 Chinese lines).

- [ ] **Step 1: Translate all Chinese comments in install.sh**

Translate comment lines and inline comments; keep code, strings, and stage names (`preflight → pacman → yay → aur → system → services → user → dotfiles → themes → mpv → post`) verbatim. Stage header comments match the AGENTS.md stage list.

- [ ] **Step 2: Verify no Chinese comments remain**

Run: `rg '[一-龥]' install.sh`
Expected: no matches (unless a user-facing string is Chinese — translate only comments).

- [ ] **Step 3: Verify static check**

Run: `shellcheck install.sh`
Expected: exit 0, no warnings.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "docs: translate install.sh comments to English"
```

---

### Task 3: shell dotfiles (.zshrc, direnvrc, git config, packages lists)

**Files:**
- Modify: `dotfiles/.zshrc`
- Modify: `dotfiles/.config/direnv/direnvrc`
- Modify: `dotfiles/.config/git/config`
- Modify: `packages/pacman.txt`
- Modify: `packages/aur.txt`

**Interfaces:**
- Consumes: nothing.
- Produces: English comments and section headers (`# === 浏览器 ===` → `# === Browsers ===`, etc.). Package names unchanged.

- [ ] **Step 1: Translate comments/headers in the five files**

`.zshrc` (12 Chinese lines): translate section banners (环境变量/历史记录/别名/工具集成) and inline notes (pnpm global dir, try, yazi cd-on-exit, atuin Ctrl+R note, syntax-highlighting last). Keep `# === ... ===` banner style.

`.git/config` (1 line): `# catppuccin 主题（本仓库 dotfiles 自带）` → `# catppuccin theme (ships with this repo's dotfiles)`.

`direnvrc` (1 line): `# direnv 自定义布局` → `# direnv custom layouts`.

`packages/pacman.txt` + `packages/aur.txt`: translate `# === 分类 ===` headers to English (`# === Base tools ===`, `# === System services ===`, `# === Browsers ===`, etc.). Keep package lines and blank-line structure.

- [ ] **Step 2: Verify**

Run: `rg '[一-龥]' dotfiles/.zshrc dotfiles/.config/direnv/direnvrc dotfiles/.config/git/config packages/pacman.txt packages/aur.txt`
Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add dotfiles/.zshrc dotfiles/.config/direnv/direnvrc dotfiles/.config/git/config packages/pacman.txt packages/aur.txt
git commit -m "docs: translate shell dotfile comments to English"
```

---

### Task 4: Hyprland stack (hyprland.lua, hypridle, hyprlock, hyprpaper)

**Files:**
- Modify: `dotfiles/.config/hypr/hyprland.lua`
- Modify: `dotfiles/.config/hypr/hypridle.conf`
- Modify: `dotfiles/.config/hypr/hyprlock.conf`
- Modify: `dotfiles/.config/hypr/hyprpaper.conf`

**Interfaces:**
- Consumes: nothing.
- Produces: English `--`/`#` comments. Lua config values untouched (monitor `DP-1` scale 1.25, binds, env). Keep 4-space indent, aligned `=`.

- [ ] **Step 1: Translate comments in hyprland.lua**

Translate header (0.55 hyprlang deprecation, wiki link), monitor note (`hyprctl monitors`), XWayland fractional-scaling note (WeChat .desktop QT_SCALE_FACTOR), fcitx5 IM notes (GTK_IM_MODULE warning, XMODIFIERS), Qt/Electron platform notes, cursor theme note, touchpad gestures note, section banners (程序启动/截图), inline notes (Caps→Ctrl, goldendict Super+T, clipboard history, color picker). Inline comments use `-- comment` after code; keep code unchanged. Do NOT touch the Lua DSL strings in the file's code.

- [ ] **Step 2: Translate comments in hypridle.conf, hyprlock.conf, hyprpaper.conf**

hypridle: header + per-listener comments (5 min lock, 10 min dpms, 30 min suspend) — keep the `hl.dsp.dpms(...)` command forms verbatim.
hyprlock: header, blur-wallpaper hint comment, `--time-str`/`--date-str` notes. Keep `placeholder_text` 输入密码… in Chinese (UI text).
hyprpaper: header, install.sh wallpaper-copy note, 0.8+ block-syntax note.

- [ ] **Step 3: Verify**

Run: `rg '[一-龥]' dotfiles/.config/hypr/`
Expected: only the hyprlock `输入密码…` placeholder remains.

- [ ] **Step 4: Lua syntax check**

Run: `luac -p dotfiles/.config/hypr/hyprland.lua`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add dotfiles/.config/hypr/
git commit -m "docs: translate hyprland stack comments to English"
```

---

### Task 5: app configs (kitty, mpv, dunst, zathura, satty, rofi, waybar)

**Files:**
- Modify: `dotfiles/.config/kitty/kitty.conf`
- Modify: `dotfiles/.config/mpv/mpv.conf`
- Modify: `dotfiles/.config/dunst/dunstrc`
- Modify: `dotfiles/.config/zathura/zathurarc`
- Modify: `dotfiles/.config/satty/config.toml`
- Modify: `dotfiles/.config/rofi/config.rasi`
- Modify: `dotfiles/.config/waybar/config.jsonc`
- Modify: `dotfiles/.config/waybar/style.css`

**Interfaces:**
- Consumes: nothing.
- Produces: English comments. UI strings stay Chinese: waybar `format-disconnected` 离线, `format-muted` 静音.

- [ ] **Step 1: Translate comments in kitty, mpv, dunst, zathura, satty**

kitty.conf: header, docs link note, catppuccin theme note.
mpv.conf: header, catppuccin theme note, mpv-mpris note.
dunstrc: header, catppuccin palette comment.
zathurarc: header (`zathura 配置 — catppuccin mocha` → `zathura config — catppuccin mocha`).
satty/config.toml: header, copy-on-exit note, initial-tool note.

- [ ] **Step 2: Translate comments in rofi config.rasi and waybar files**

config.rasi: `/* 主题文件在 ~/.local/share/rofi/themes/… */` → English.
waybar/config.jsonc: header, laptop wlo1 note, module comments (磁盘空间/网络/CPU 负载/内存/音量/时间). Keep `离线`/`静音` strings.
waybar/style.css: header `/* Waybar — catppuccin mocha 主题 */` → English.

- [ ] **Step 3: Verify**

Run: `rg '[一-龥]' dotfiles/.config/kitty/kitty.conf dotfiles/.config/mpv/mpv.conf dotfiles/.config/dunst/dunstrc dotfiles/.config/zathura/zathurarc dotfiles/.config/satty/config.toml dotfiles/.config/rofi/config.rasi`
Expected: no matches.
Run: `rg '[一-龥]' dotfiles/.config/waybar/`
Expected: only 离线/静音 format strings.

- [ ] **Step 4: Commit**

```bash
git add dotfiles/.config/kitty/kitty.conf dotfiles/.config/mpv/mpv.conf dotfiles/.config/dunst/dunstrc dotfiles/.config/zathura/zathurarc dotfiles/.config/satty/config.toml dotfiles/.config/rofi/config.rasi dotfiles/.config/waybar/
git commit -m "docs: translate app config comments to English"
```

---

### Task 6: fcitx5, fonts, nvim, desktop entries

**Files:**
- Modify: `dotfiles/.config/fcitx5/conf/classicui.conf`
- Modify: `dotfiles/.config/fcitx5/conf/rime.conf`
- Modify: `dotfiles/.config/fontconfig/fonts.conf`
- Modify: `dotfiles/.config/nvim/lua/plugins/flash.lua`
- Modify: `dotfiles/.local/share/applications/wechat.desktop`

**Interfaces:**
- Consumes: nothing.
- Produces: English comments only. `.desktop` Name/Comment display strings stay Chinese.

- [ ] **Step 1: Translate comments**

classicui.conf: `# catppuccin 主题（install.sh 会 clone …）` → English.
rime.conf: `# 输入中从中文切换为英文时保留原始输入…` → English (comment describing input behavior; the config value stays).
fonts.conf: `<!-- 兜底：个别仍请求 Inter 的应用统一走 Noto Sans -->` → English XML comment; font name values unchanged.
flash.lua: `-- 禁用 flash 对 s/S 的占用，恢复 Vim 默认行为` → English.
wechat.desktop: translate the `# 覆盖系统级 desktop：XWayland 下 1.25 分数缩放…` comment; keep `Name[zh_CN]=微信` / `Comment[zh_CN]=微信桌面版`.

- [ ] **Step 2: Verify**

Run: `rg '[一-龥]' dotfiles/.config/fcitx5/ dotfiles/.config/fontconfig/ dotfiles/.config/nvim/lua/plugins/flash.lua dotfiles/.local/share/applications/`
Expected: only `.desktop` display strings (微信, Kimi AI 智能助手, Google 邮箱, Git 代码托管, DeepSeek AI 聊天) remain.

- [ ] **Step 3: Commit**

```bash
git add dotfiles/.config/fcitx5/ dotfiles/.config/fontconfig/ dotfiles/.config/nvim/lua/plugins/flash.lua dotfiles/.local/share/applications/
git commit -m "docs: translate remaining config comments to English"
```

---

### Task 7: docs/superpowers history docs

**Files:**
- Modify: `docs/superpowers/plans/2026-08-12-web-apps.md`
- Modify: `docs/superpowers/specs/2026-08-12-web-apps-design.md`

**Interfaces:**
- Consumes: nothing.
- Produces: English versions of the historical web-apps plan (88 Chinese lines) and design doc (43 Chinese lines). Facts, code blocks, and file paths unchanged.

- [ ] **Step 1: Translate plans doc**

Translate all Chinese prose (task descriptions, notes) in `docs/superpowers/plans/2026-08-12-web-apps.md` to English. Keep code blocks, paths, and checkbox structure verbatim.

- [ ] **Step 2: Translate spec doc**

Translate all Chinese prose in `docs/superpowers/specs/2026-08-12-web-apps-design.md` to English. Keep code blocks and paths verbatim.

- [ ] **Step 3: Verify**

Run: `rg '[一-龥]' docs/superpowers/`
Expected: no matches.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/
git commit -m "docs: translate web-apps plan and spec to English"
```

---

### Task 8: final sweep + verification

**Files:**
- (none; verification only)

**Interfaces:**
- Consumes: all previous tasks.

- [ ] **Step 1: Repo-wide Chinese scan**

Run: `rg '[一-龥]' --hidden -g '!.git'`
Expected: only allowed files/strings remain — `README.zh.md` (whole file), README switcher links, `.desktop` display strings, waybar 离线/静音, hyprlock 输入密码….

- [ ] **Step 2: Static checks**

Run: `shellcheck install.sh && luac -p dotfiles/.config/hypr/hyprland.lua`
Expected: both exit 0.

- [ ] **Step 3: Final commit (if anything was missed and fixed)**

```bash
git add -A && git commit -m "docs: final English-conversion sweep"
```

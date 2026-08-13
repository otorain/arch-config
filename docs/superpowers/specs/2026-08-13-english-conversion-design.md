# English Conversion Design

Date: 2026-08-13

## Goal

Convert all docs and code comments in this repo to English. Commit messages stay in English (already the convention).

## Scope

### Translate to English

- Code comments (`#`, `//`, `--`, `/* */`, `<!-- -->`) in all shell/lua/jsonc/conf files:
  - `install.sh`
  - `dotfiles/.zshrc`
  - `dotfiles/.config/hypr/hyprland.lua`, `hypridle.conf`, `hyprlock.conf`, `hyprpaper.conf`
  - `dotfiles/.config/kitty/kitty.conf`
  - `dotfiles/.config/mpv/mpv.conf`
  - `dotfiles/.config/dunst/dunstrc`
  - `dotfiles/.config/zathura/zathurarc`
  - `dotfiles/.config/satty/config.toml`
  - `dotfiles/.config/direnv/direnvrc`
  - `dotfiles/.config/git/config`
  - `dotfiles/.config/fontconfig/fonts.conf`
  - `dotfiles/.config/fcitx5/conf/classicui.conf`, `rime.conf`
  - `dotfiles/.config/nvim/lua/plugins/flash.lua`
  - `dotfiles/.config/rofi/config.rasi`
  - `dotfiles/.config/waybar/config.jsonc`, `style.css`
  - `dotfiles/.local/share/applications/*.desktop` (comments only)
  - `packages/pacman.txt`, `packages/aur.txt` (section headers)
- Docs:
  - `AGENTS.md` — rewritten fully in English
  - `docs/superpowers/plans/2026-08-12-web-apps.md`
  - `docs/superpowers/specs/2026-08-12-web-apps-design.md`
- `README.md` is already English (no change).

### Keep in Chinese

- `README.zh.md` — remains the Chinese mirror; the dual-README sync convention stays.
- User-facing UI text:
  - `.desktop` `Name[zh_CN]`/`Comment` display strings (e.g. 微信, Kimi AI 智能助手)
  - waybar format strings (离线, 静音)
  - hyprlock placeholder text (输入密码…)
  - README language-switcher link labels ([English] | [中文])
  - rime/input-method related display strings

## Convention change

`AGENTS.md` (now in English) states:

- Docs and code comments are in English.
- `README.zh.md` stays Chinese as the zh mirror; keep both READMEs in sync.
- User-facing UI text stays Chinese.
- Commit messages are in English.

## Verification

- `shellcheck install.sh` passes
- `luac -p dotfiles/.config/hypr/hyprland.lua` passes

## Amendments

Later on 2026-08-13 the keep-list was narrowed:

- install.sh user-facing output strings (info/ok/warn/die/echo messages) translated to English.
- Remaining Chinese inside code blocks of `docs/superpowers/plans/2026-08-12-web-apps.md` and `docs/superpowers/specs/2026-08-12-web-apps-design.md` translated to English (samples no longer byte-match git history / shipped .desktop files; accepted).
- `AGENTS.md` convention now reads: UI text stays Chinese (desktop entry names/comments, waybar labels, hyprlock placeholder); everything else — comments, docs, install.sh output — is English.

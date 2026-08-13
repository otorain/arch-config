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

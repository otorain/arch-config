# Web Apps Deployed with the System (web-apps) Design

Date: 2026-08-12
Status: confirmed

## Background and goals

Install several web pages (DeepSeek, Kimi, Gmail, GitHub) as standalone apps, **reproducibly deployed with the system install script**.

Current problem: DeepSeek / Kimi are real Chrome PWAs installed interactively (`--app-id=` + the
`Web Applications/Manifest Resources/<appid>` inside the Chrome profile); their data lives in Chrome's internal storage, is lost on a system reinstall,
and is not reproducible. hyprland.lua already has window rules for the old PWAs (`chrome-<appid>-Default` class names).

## Mechanism decision

Adopt the **declarative app mode** (option A):

- Put `.desktop` files in `dotfiles/.local/share/applications/` with `Exec=google-chrome-stable --app="URL"`.
- No dependency on Chrome profile internals — Chrome upgrades can't break it; a 1:1 deploy via the dotfiles stage completes the install.
- Shares the main Chrome session (Gmail/GitHub stay logged in with the browser).
- Rejected: copying real PWA profile data (depends on Chrome's internal format, fragile).

### Window class name notes

`--app=URL` window class names are derived from the URL (e.g. `chrome-<url>-Default`); `--class` / `StartupWMClass`
are ignored by Chrome under Wayland (Chromium issue 441482388). So the class names in the window rules must be measured per site during implementation
(`hyprctl clients -j`) and written as anchored regexes.

## New files

```
dotfiles/.local/share/applications/
  deepseek.desktop  kimi.desktop  gmail.desktop  github.desktop
dotfiles/.local/share/icons/hicolor/256x256/apps/
  deepseek.png  kimi.png  gmail.png  github.png
```

`.desktop` template (all 4 files are isomorphic):

```ini
[Desktop Entry]
Version=1.0
Name=DeepSeek
Comment=DeepSeek AI 聊天
Exec=google-chrome-stable --app="https://chat.deepseek.com"
Icon=deepseek
Keywords=deepseek;ai;chat;
Terminal=false
Type=Application
Categories=Network;WebBrowser;
```

- `StartupWMClass` is omitted (ineffective, see above).
- `Icon=` uses the icon name, resolved via the FDO icon theme lookup; icons go in `hicolor/256x256/apps/` (the size subdirectory is required).
- Don't use an absolute-path `Icon` (it would hardcode the home directory into the `.desktop` file).

App list (URLs to be re-checked at implementation time):

| App     | URL                        | Name  | Keywords |
|---------|----------------------------|-------|----------|
| DeepSeek| https://chat.deepseek.com   | DeepSeek | deepseek;ai;chat; |
| Kimi    | https://www.kimi.com        | Kimi  | kimi;ai;chat; |
| Gmail   | https://mail.google.com     | Gmail | gmail;mail; |
| GitHub  | https://github.com          | GitHub | github;git; |

Icon source: each site's favicon, converted to PNG (256x256) and committed to the repo.

## hyprland.lua changes

Add one window rule each for DeepSeek / Kimi (keeping the scratchpad behavior):

```lua
hl.window_rule({
  name = "float-deepseek",
  match = { class = "^(chrome-chat\\.deepseek\\.com.*-Default)$" },
  float = true,
  size = "1200 800",
  center = true,
  workspace = "special:deepseek silent",
})
```

- Class names follow the measured values (the example above is only the expected format).
- The old `chrome-<appid>-Default` rules stay (the old PWAs on this machine are not cleaned up).
- Gmail / GitHub are ordinary windows: no window rules, no keybinds.
- Keybinds (mod+Q / mod+grave) unchanged.

## install.sh changes

No new stage. Append at the end of the `dotfiles` stage (idempotent):

```bash
as_user_home update-desktop-database "$TARGET_HOME/.local/share/applications" 2>/dev/null || true
as_user_home gtk-update-icon-cache -f "$TARGET_HOME/.local/share/icons/hicolor" 2>/dev/null || true
```

The `dotfiles` stage already copies everything via `find . -type f` and chowns `~/.local/share`; no other changes needed.

## Verification

- `shellcheck install.sh`, `luac -p dotfiles/.config/hypr/hyprland.lua`
- Launch each site once, measure class names with `hyprctl clients -j`, and check the window rules
- DeepSeek / Kimi land in the special workspace and float
- rofi (mod+D) can find the 4 apps

## Known status (confirmed out of scope)

- The old interactive PWAs on this machine are not cleaned up; duplicate DeepSeek / Kimi entries in rofi are expected in the short term. A fresh install has no such problem.
- Gmail / GitHub are ordinary windows, no special behavior.

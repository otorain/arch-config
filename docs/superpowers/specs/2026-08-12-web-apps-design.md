# 网页应用随系统部署（web-apps）设计

日期：2026-08-12
状态：已确认

## 背景与目标

把若干网页（DeepSeek、Kimi、Gmail、GitHub）作为独立应用安装，且**随系统安装脚本可复现部署**。

现状问题：DeepSeek / Kimi 目前是交互式安装的真实 Chrome PWA（`--app-id=` + Chrome profile 内
`Web Applications/Manifest Resources/<appid>`），数据存在 Chrome 内部存储，重装系统即丢失，
不可复现。hyprland.lua 中已有针对旧 PWA 的窗口规则（`chrome-<appid>-Default` 类名）。

## 机制决策

采用**声明式 app 模式**（A 方案）：

- 在 `dotfiles/.local/share/applications/` 放 `.desktop` 文件，`Exec=google-chrome-stable --app="URL"`。
- 不依赖 Chrome profile 内部数据，升级不怕碎，随 dotfiles 阶段 1:1 部署即完成安装。
- 共享主 Chrome 会话（Gmail/GitHub 登录态随浏览器）。
- 已被否决：复制真实 PWA profile 数据（依赖 Chrome 内部格式，易碎）。

### 窗口类名说明

`--app=URL` 窗口类名由 URL 推导（如 `chrome-<url>-Default`），`--class` / `StartupWMClass`
在 Wayland 下被 Chrome 忽略（Chromium issue 441482388）。因此窗口规则的类名必须在实现时
逐站实测（`hyprctl clients -j`），写成锚定正则。

## 新增文件

```
dotfiles/.local/share/applications/
  deepseek.desktop  kimi.desktop  gmail.desktop  github.desktop
dotfiles/.local/share/icons/hicolor/256x256/apps/
  deepseek.png  kimi.png  gmail.png  github.png
```

`.desktop` 模板（4 个文件同构）：

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

- `StartupWMClass` 不写（无效，见上）。
- `Icon=` 用图标名，走 FDO 图标主题查找；图标放 `hicolor/256x256/apps/`（尺寸子目录必需）。
- 不用绝对路径 Icon（会把家目录硬编码进 `.desktop`）。

应用清单（URL 实现时复核）：

| 应用    | URL                        | Name  | Keywords |
|---------|----------------------------|-------|----------|
| DeepSeek| https://chat.deepseek.com   | DeepSeek | deepseek;ai;chat; |
| Kimi    | https://www.kimi.com        | Kimi  | kimi;ai;chat; |
| Gmail   | https://mail.google.com     | Gmail | gmail;mail; |
| GitHub  | https://github.com          | GitHub | github;git; |

图标来源：各站点 favicon，转 PNG（256x256）提交进仓库。

## hyprland.lua 改动

DeepSeek / Kimi 各新增一条窗口规则（保留 scratchpad 行为）：

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

- 类名以实测为准（上例仅作预期格式）。
- 旧的 `chrome-<appid>-Default` 规则保留（本机旧 PWA 不清理）。
- Gmail / GitHub 为普通窗口，不加窗口规则、不加快捷键。
- 快捷键（mod+Q / mod+grave）不变。

## install.sh 改动

不新增阶段。在 `dotfiles` 阶段尾部追加（幂等）：

```bash
as_user_home update-desktop-database "$TARGET_HOME/.local/share/applications" 2>/dev/null || true
as_user_home gtk-update-icon-cache -f "$TARGET_HOME/.local/share/icons/hicolor" 2>/dev/null || true
```

dotfiles 阶段已有 `find . -type f` 全量拷贝并 chown `~/.local/share`，无需其他改动。

## 验证

- `shellcheck install.sh`、`luac -p dotfiles/.config/hypr/hyprland.lua`
- 逐站启动一次，`hyprctl clients -j` 实测类名并核对窗口规则
- DeepSeek / Kimi 落入 special 工作区且浮动
- rofi（mod+D）可搜到 4 个应用

## 已知状态（已确认不处理）

- 本机旧交互式 PWA 不清理，短期内 rofi 里 DeepSeek / Kimi 有重复项属预期；全新安装无此问题。
- Gmail / GitHub 普通窗口，无特殊行为。

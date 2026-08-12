# arch-config — 自用 Arch Linux (Hyprland) 系统配置

自用 Arch Linux (Hyprland) 桌面环境配置：安装脚本 + 配置文件一体，catppuccin-mocha（蓝色）主题。

## 使用

先用 archinstall 装好基础系统（见下文「基础安装」），然后：

```bash
git clone <你的仓库> ~/arch-config
cd ~/arch-config
./install.sh
```

重复运行安全。只跑部分阶段：

```bash
./install.sh --only pacman,aur        # 只装包
./install.sh --only dotfiles,themes   # 只铺配置
```

阶段顺序：`preflight → pacman → yay → aur → system → services → user → dotfiles → themes → mpv → post`

## 基础安装（archinstall 建议）

- 文件系统如用 btrfs，装完补 `compsize`
- 镜像源：`reflector --country China --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist`
- 时区脚本会设为 Asia/Shanghai；locale 脚本生成 en_US.UTF-8 + zh_CN.UTF-8，默认 `LANG=zh_CN.UTF-8`（终端报错保持英文 `LC_MESSAGES=en_US.UTF-8`）

## 桌面组件

- hyprland + waybar（窗口管理 / 状态栏）
- hyprlock + hypridle（锁屏 / 息屏）
- hyprpaper（壁纸）
- rofi（应用 / 表情启动器）
- grim + slurp + satty（截图标注）
- wl-clipboard + cliphist（剪贴板）
- dunst（通知）
- nwg-look（GTK 外观设置）
- hyprpolkitagent（polkit 代理）
- sddm（登录管理器，catppuccin 主题）

## 装完后的手工事项

1. **显示器**：`hyprctl monitors` 查看接口名，编辑 `~/.config/hypr/hyprland.lua` 顶部的 `hl.monitor({...})` 行（Hyprland 0.55 起 hyprlang 弃用，配置为 Lua 版）。默认 `DP-1` + 缩放 1.25，外接显示器通常用 1
2. **neovim**：配置随 dotfiles 部署（LazyVim），首次启动自动装插件并编译 tree-sitter grammar（需 gcc，已在包清单里）
3. **输入法**：重新登录后 fcitx5 自启，rime 首次会自动部署雾凇拼音（rime-ice）。想保留旧词频，复制旧系统 `~/.local/share/fcitx5/rime/*.userdb`
4. **dropbox**：`hl.exec_cmd("dropbox")` 在 hyprland.lua 里被注释掉了，装好 AUR 包后按需取消注释
5. **VirtualBox**：扩展包在 AUR `virtualbox-ext-oracle`；内核更新后如模块失效，执行 `sudo vboxreload`
6. **goldendict-ng**：词典需手动放置，见 [Dictionaries](https://github.com/xiaoyifang/goldendict-ng?tab=readme-ov-file#dictionaries) 文档（词典文件可放 `~/.local/share/goldendict`，然后在设置里添加目录）。登录自启常驻托盘，`Super+T` 通过单实例 IPC 转发查询词，免冷启动

## 键位

| 快捷键 | 功能 |
| --- | --- |
| `Super+Return` | 终端 |
| `Super+D` | 应用启动器 |
| `Super+E` | 表情选择 |
| `Super+Ctrl+C` | 浏览器（Chrome） |
| `Super+Ctrl+F` | Firefox |
| `Super+Ctrl+R` | RubyMine |
| `Super+Ctrl+P` | PyCharm |
| `Super+F3` | 文件管理器（pcmanfm） |
| `Super+T` | 选中文字查词典（goldendict） |
| `Super+O` | 剪贴板历史（cliphist + rofi） |
| `Super+P` | 区域截图（satty 标注） |
| `Print` | 全屏截图 |
| `Shift+Print` | 区域截图（无标注） |
| `Super+Q` | DeepSeek scratchpad |
| `Super+\`` | Kimi scratchpad |
| `Alt+W` | 微信 scratchpad |
| `Super+Shift+Q` | 关闭窗口 |
| `Super+F` | 全屏 |
| `Super+Shift+Space` | 浮动 |
| `Super+W` | 标签组 |
| `Super+V` | 预置方向分屏（下） |
| `Super+;` | 预置方向分屏（右） |
| `Super+H/J/K/L` | 焦点（含方向键） |
| `Super+Shift+H/J/K/L` | 移动窗口（含方向键） |
| `Alt+Tab` | 前一工作区 |
| `Super+Ctrl+←/→` | 相邻工作区 |
| `Super+1..9` | 工作区 |
| `Super+Shift+1..9` | 移到工作区 |
| `Super+滚轮` | 切换工作区 |
| `Super+鼠标左键` | 拖动窗口 |
| `Super+鼠标右键` | 缩放窗口 |
| `Super+R` | resize 模式（H/J/K/L 调整，Enter/Esc 退出） |
| `Super+Ctrl+L` | 锁屏 |
| `Super+0` | 电源菜单 |
| `Super+Shift+E` | 退出 Hyprland |
| `Super+M` | 隐藏/显示状态栏 |
| `Super+Shift+D` | 重启 dunst |
| `Super+Shift+C` | 重载配置 |
| `XF86AudioRaiseVolume` | 音量 + |
| `XF86AudioLowerVolume` | 音量 − |
| `XF86AudioMute` | 静音 |
| `XF86MonBrightnessUp` | 亮度 + |
| `XF86MonBrightnessDown` | 亮度 − |
| `XF86AudioPlay` | 播放/暂停 |
| `XF86AudioNext` | 下一首 |
| `XF86AudioPrev` | 上一首 |

## 可能装不上的包（脚本会警告跳过）

AUR 包名会变动。若 `zed` 官方仓库版本不合意可用 AUR `zed-preview-bin`；`pycharm`/`rubymine` 是 AUR 构建（下载官方 tarball），也可用 JetBrains Toolbox 手动装。

## 文件结构

```
.
├── install.sh          # 主脚本（幂等，支持 --only）
├── packages/
│   ├── pacman.txt      # 官方仓库（每行一包，# 注释）
│   └── aur.txt         # AUR
├── assets/
│   └── colin-watts.jpg # SDDM / 桌面壁纸
└── dotfiles/           # 原样映射到 ~（已有文件直接覆盖）
    ├── .zshrc
    ├── .pi/agent/      # pi-coding-agent 配置
    ├── .config/hypr/   # hyprland.lua + hyprlock + hypridle + hyprpaper
    ├── .config/waybar/ # waybar 模块
    ├── .config/kitty/  # 含 catppuccin mocha 主题
    ├── .config/rofi/ + .local/share/rofi/themes/
    ├── .config/dunst/  # 含 mocha 配色
    ├── .config/mpv/    # uosc/thumbfast/sponsorblock 由 AUR 提供
    ├── .config/git/    # delta + catppuccin
    ├── .config/fcitx5/ # fcitx5 配置（profile/classicui/rime.conf）
    ├── .local/share/fcitx5/rime/ # 雾凇拼音 default.custom.yaml
    ├── .config/atuin/  # 含 catppuccin 主题
    ├── .config/Kvantum/ # qt 主题（catppuccin-mocha-blue）
    ├── .config/gtk-3.0/ + .config/fontconfig/
    ├── .config/direnv/ # 含 layout_uv
    ├── .config/nvim/   # LazyVim 配置（init.lua + lua/config + lua/plugins）
    ├── .config/satty/ + .config/zathura/ + .config/pcmanfm/
    ├── .config/zed/   # settings.json
    ├── .config/mimeapps.list + .config/user-dirs.{conf,dirs}
    ├── .local/share/applications/ # 覆盖系统 .desktop（deepseek/github/gmail/kimi/wechat 等）
    ├── .local/share/icons/ # PWA 图标（deepseek/github/gmail/kimi）
    └── .local/share/catppuccin_mocha-zsh-syntax-highlighting.zsh
```

## 许可证

MIT，详见 [LICENSE](LICENSE)。

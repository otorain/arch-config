# 日常使用指南

> 面向已经装好系统的日常使用。README 有完整的快捷键速查总表；本篇按场景讲解机制与用法，
> 全部键位以 `playbooks/roles/software/templates/hyprland/hyprland.lua.j2` 为准。

## 快捷键按场景

### 启动应用

| 键位 | 动作 |
| --- | --- |
| `Super+Return` | 终端（kitty） |
| `Super+D` | 应用启动器（rofi drun） |
| `Super+E` | emoji 选择器（rofi） |
| `Super+0` | 电源菜单（rofi-power-menu） |
| `Super+Ctrl+C` / `+F` | Chrome / Firefox |
| `Super+Ctrl+R` / `+P` | RubyMine / PyCharm |
| `Super+F3` | 文件管理器（pcmanfm） |
| `Super+T` | 用 goldendict 查当前选中的词 |

补充几点：

- rofi 是 layer-shell surface，配置里专门跳过了它的开关动画，菜单瞬时弹出（见 [应用说明 · rofi](apps.md#rofi)）。
- `Super+T` 的 goldendict 开机就在后台常驻（托盘），查词是把内容转发给常驻实例，没有冷启动。
- 每次登录会自动打开 Chrome（落在工作区 3）和 kitty（落在工作区 2），不打断当前焦点（silent）。

### 窗口管理

| 键位 | 动作 |
| --- | --- |
| `Super+H/J/K/L`（或方向键） | 切换焦点 |
| `Super+Shift+H/J/K/L`（或方向键） | 移动窗口 |
| `Super+Shift+Q` | 关闭窗口 |
| `Super+F` | 全屏 |
| `Super+Shift+Space` | 浮动/平铺切换 |
| `Super+W` | 把窗口并入/拆出 tab 组 |
| `Super+Shift+V` / `Super+;` | 预设下一次分割方向：向下 / 向右（dwindle preselect） |
| `Super+Shift+S` | 切换布局：dwindle ↔ scrolling（scrolling 列宽 0.75） |
| `Super+左键拖动` / `Super+右键拖动` | 移动 / 调整窗口 |

调整窗口大小有两种方式：

- **直接微调**——`Super+=` / `Super+-` 调宽，`Super+Shift+=` / `Super+Shift+-` 调高，步长 30px，可按住连发。dwindle 布局下"调宽"到底是涨是缩取决于窗口在分割边的哪一侧，脚本会先发一个 8px 的探测再根据实际变化修正方向，所以按键语义永远是"变宽/变窄"，不用关心分割方向。
- **resize 子模式**——`Super+R` 进入，之后单按 `H/J/K/L`（或方向键）每次调 20px，`Enter` 或 `Esc` 退出。

### 工作区

| 键位 | 动作 |
| --- | --- |
| `Super+1..9` | 切换到工作区 |
| `Super+Shift+1..9` | 把窗口移到工作区并跟随 |
| `Alt+Tab` | 回到上一个工作区 |
| `Super+Ctrl+←/→` | 相邻工作区 |
| `Super+滚轮` | 逐个切换工作区 |

**scratchpad（便签窗口）**：`Super+Q` 呼出 [DeepSeek](apps.md#deepseek)、``Super+` `` 呼出 [Kimi](apps.md#kimi)、`Alt+W` 呼出[微信](apps.md#wechat)。三者由 pyprland 管理：按一次从屏幕顶部滑出到当前工作区，再按一次滑回隐藏；窗口常驻不关闭，首次呼出时才启动。从 rofi 启动它们也会被 pyprland 按窗口 class 接管。

### 截图与取色

| 键位 | 动作 |
| --- | --- |
| `Super+P` | 框选区域 → 进 satty 标注 → 保存到 `~/Pictures/satty-<时间戳>.png` |
| `Print` | 全屏截图，直接存 `~/Pictures/screenshot-<时间戳>.png` |
| `Shift+Print` | 框选区域，直接存 `~/Pictures/screenshot-<时间戳>.png` |
| `Super+Shift+P` | hyprpicker 取色，自动复制十六进制值到剪贴板 |

流程细节见下文[截图工作流](#截图工作流)。

### 剪贴板

| 键位 | 动作 |
| --- | --- |
| `Super+C` / `Super+V` | 复制 / 粘贴（terminal-aware） |
| `Super+X` | 剪切 |
| `Super+O` | 剪贴板历史（cliphist + rofi） |

**terminal-aware 的原理**：`Super+C/V` 按下时，脚本读取焦点窗口的 class，如果在终端列表（kitty、alacritty、foot、wezterm、ghostty、gnome-terminal、konsole、xfce4-terminal）里就注入 `Ctrl+Shift+C/V`，否则注入 `Ctrl+C/V`——所以在终端和普通 GUI 里都是同一对键位。注入用"按下/抬起"两次事件、中间隔 50ms 定时器的方式，绕过 Hyprland 的 send_shortcut 卡键 bug（上游 issue #14099）。`Super+X` 不做终端判断（终端里剪切本来就没有标准键位），统一发 `Ctrl+X`。

历史记录见下文[剪贴板历史](#剪贴板历史)。

### 系统控制

| 键位 | 动作 |
| --- | --- |
| `Super+Ctrl+L` | 锁屏（loginctl → hyprlock） |
| `Super+Shift+E` | 退出 Hyprland |
| `Super+M` | 显示/隐藏状态栏（给 waybar 发 SIGUSR1） |
| `Super+Shift+D` | 重启 dunst 通知守护 |
| `Super+Shift+C` | 重新加载 Hyprland 配置 |
| 音量/亮度/播放键 | `XF86*` 多媒体键 |

两点说明：

- 锁屏是 `loginctl lock-session` 触发 hyprlock；放着不动时由 hypridle 按超时自动锁屏、关屏。
- 多媒体键带 `locked = true`，锁屏状态下也能调音量亮度；音量和亮度键按住会连续调节（repeating）。
- 另外，Caps Lock 被映射为 Ctrl（`ctrl:nocaps`）。

## waybar 状态栏

三段布局：左边是工作区和当前窗口标题，中间是时钟和天气，右边是系统状态与托盘。

| 模块 | 显示内容 | 点击行为 |
| --- | --- | --- |
| workspaces | 工作区编号 | 见下方已知问题 |
| window | 焦点窗口标题（最长 60 字符） | — |
| clock | `星期六 2026.10.03 14:05` 格式（中文 locale） | 打开/关闭农历日历弹层 |
| weather | 默认城市的天气图标与温度 | 打开/关闭城市列表弹层 |
| disk | 根分区剩余空间（80% 警告、90% 严重） | — |
| network | 当前 IP（交替显示 essid + 上下行速率） | 切换显示格式 |
| cpu | 使用率%，每秒刷新 | — |
| memory | 已用/总量 GB | 切换显示 swap |
| pulseaudio | 音量%（静音显示"静音"） | 打开 pavucontrol |
| tray | 托盘图标 | — |

已知问题：waybar 0.15.0 下**点击工作区编号不能切换**——模块内部写死了旧版 IPC 调用，被 Hyprland 0.55+ 拒绝。上游 master 已修，0.16 发布即自愈；这期间请用 `Super+数字` 切换，不要改配置绕过（详见 [应用说明 · waybar](apps.md#waybar)）。

**天气模块**：数据来自高德（Amap），API key 放在 `~/.config/weather/amap-key`（一行），每 15 分钟刷新。栏上只显示一个默认城市；点击模块弹出城市列表，选中即切换默认城市并立即生效（脚本给 waybar 发 SIGUSR2 重载）。

**日历弹层**：点击时钟打开农历月历——周日起始的格子，每天下面标农历日期，含节日、节气和官方调休徽标（休/班）。`‹ ›` 按钮、方向键或滚轮翻月，点击某天复制它的 ISO 日期。

**弹层共性**：两个弹层都是全屏透明的 gtk4-layer-shell surface，通过 AT-SPI 定位、锚定在各自模块正下方；按 `Esc`、点击卡片外任意处、或再点一次模块都会关闭。实现机制见[架构与原理](architecture.md)。整个状态栏可用 `Super+M` 显隐。

## 输入法（fcitx5 + rime-ice）

- **输入法组**：默认 `keyboard-us` + `rime`（雾凇拼音 `rime_ice` 方案），切换键是 fcitx5 默认的 `Ctrl+Space`（仓库没有部署快捷键配置；想改就用 `fcitx5-configtool`）。
- **中英切换行为**：从中文切到英文时提交已输入的原始字母，而不是第一个候选词（`files/fcitx5/rime.conf`）。
- **皮肤**：catppuccin-mocha-blue，主题文件由 settings 角色装到 `~/.local/share/fcitx5/themes`（见 [应用说明 · fcitx5](apps.md#fcitx5)）。
- **环境变量**：`QT_IM_MODULE=fcitx`、`XMODIFIERS=@im=fcitx` 等已在 `hyprland.lua` 里设好；GTK 应用刻意不设 `GTK_IM_MODULE`——原生 Wayland 的 GTK 应用走 text-input-v3，设了反而会触发 fcitx5 的警告。
- **用户词库**：`~/.local/share/fcitx5/rime/*.userdb`。换机器时把旧系统的这些文件拷过来，词频数据就保留了。

## 截图工作流

三种截图键位见[截图与取色](#截图与取色)，这里说 `Super+P` 的完整流程：

1. `slurp` 框选区域（十字准星，按 `Esc` 取消）
2. `grim` 截取选区，通过管道送给 satty
3. satty 打开标注界面（浮动窗口，初始工具是画笔）：箭头、矩形、文字、马赛克等
4. 保存或复制都写入 `~/Pictures/satty-<时间戳>.png`——配置里 `save-after-copy = true`，复制到剪贴板（`wl-copy`）时也会同时存盘

所有截图按时间戳命名，集中在 `~/Pictures/` 下。配置见 [应用说明 · satty](apps.md#satty)。

## 剪贴板历史

登录时有两条 `wl-paste --watch cliphist store` 在后台跑，文字和图片都会进历史。

`Super+O` 弹出 rofi 列表（最新的在最上），回车选中即解码并 `wl-copy` 到剪贴板，再 `Super+V` 或 `Ctrl+V` 粘贴。

## 笔记 scratchpad

`Super+N` 打开笔记 picker（脚本见 [应用说明 · scratchpad](apps.md#scratchpad)）：

- 笔记存放在 `~/.scratchpads/*.md`，picker 按修改时间倒序列出
- 每行显示首行预览（去掉 markdown 标题符号和缩进，取 60 字符）和相对时间（"刚刚"、"5 分钟前"、"3 天前"……）
- 第一行永远是"新建"，回车创建 `scratch-<时间戳>.md`
- 选中已有笔记回车，在浮动的 kitty 窗口（800×600 居中）里用 nvim 打开
- `Ctrl+D` 删除当前选中的笔记，会再弹一次"取消/删除"确认

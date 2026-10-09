# 应用说明

> 31 个 app，按类别分组。每个 app 一节：装了什么包、部署了哪些文件、使用要点与注意事项。
> 包清单见 `playbooks/roles/software/tasks/_pacman.yml`（官方仓库）与 `_aur.yml`（AUR）。
>
> 图例：`backup: true` 表示该文件会被对应软件在运行时改写（如 zed 的设置），
> playbook 覆盖前会自动备份一份。

分类导航：[桌面组件](#桌面组件) · [Shell 与终端](#shell-与终端) · [输入法与中文环境](#输入法与中文环境) · [AI 工具](#ai-工具) · [开发工具](#开发工具) · [日常应用](#日常应用)

## 桌面组件

### hyprland

窗口管理器（Wayland compositor），整个桌面的核心。

- **包**：官方仓库 `hyprland`、`xdg-desktop-portal-hyprland`、`xdg-desktop-portal-gtk`、`hyprpolkitagent`、`qt5-wayland`、`qt6-wayland`
- **部署**：
  - `templates/hyprland/hyprland.lua.j2` → `~/.config/hypr/hyprland.lua`（模板，消费 host_vars 的 `monitor` / `scale`）
  - `assets/colin-watts.jpg` → `~/.config/hypr/wallpaper.jpg`
- **要点**：配置是 Lua（Hyprland 0.55+ 已弃用 hyprlang），全部键位、窗口规则、自启动都在这里；日常用法见[日常使用指南](usage.md)。
- **注意**：`hyprland.lua` 是渲染产物，手改会在下次 playbook 运行时被覆盖；换显示器/改缩放请改 host_vars，见[维护与开发](maintenance.md)。

### hypridle

空闲守护：超时后锁屏、关屏。

- **包**：官方仓库 `hypridle`
- **部署**：`files/hypridle/hypridle.conf` → `~/.config/hypr/hypridle.conf`
- **要点**：到时间先调 hyprlock 锁屏，再关显示器（dpms）。
- **注意**：开关显示器的命令是 `hyprctl dispatch 'hl.dsp.dpms(...)'`——`hyprctl dispatch` 只是运载工具，载荷是 Lua DSL 表达式；0.55+ 拒绝的是 `hyprctl dispatch dpms off` 这种旧式写法。

### hyprlock

锁屏界面。

- **包**：官方仓库 `hyprlock`
- **部署**：`files/hyprlock/hyprlock.conf` → `~/.config/hypr/hyprlock.conf`
- **要点**：由 hypridle 自动触发，或 `Super+Ctrl+L` 手动锁定。

### hyprpaper

壁纸守护进程。

- **包**：官方仓库 `hyprpaper`
- **部署**：`files/hyprpaper/hyprpaper.conf` → `~/.config/hypr/hyprpaper.conf`
- **要点**：引用的壁纸文件是 `~/.config/hypr/wallpaper.jpg`（由 hyprland app 部署）。

### waybar

状态栏。

- **包**：官方仓库 `waybar`、`python-gobject`（弹层脚本依赖）、`gtk4-layer-shell`（弹层依赖）
- **部署**：
  - `templates/waybar/config.jsonc.j2` → `~/.config/waybar/config.jsonc`（模板，消费 host_vars 的 `net_interface`）
  - `files/waybar/style.css` → `~/.config/waybar/style.css`
  - `files/waybar/weather.py`、`calendar.py`、`waybar_geom.py` → `~/.local/bin/`
- **要点**：模块用法与天气/日历弹层见[日常使用指南](usage.md)；弹层实现机制见[架构与原理](architecture.md)。配置、样式或脚本变更会通过 handler 自动 reload waybar。
- **注意**：waybar 0.15.0 的工作区点击切换失效是已知上游问题（master 已修，0.16 发布解决），不要用配置绕过，也不要换 waybar-git。

### dunst

通知守护进程。

- **包**：官方仓库 `dunst`、`libnotify`（提供 `notify-send`）
- **部署**：`files/dunst/dunstrc` → `~/.config/dunst/dunstrc`
- **要点**：`Super+Shift+D` 可重启 dunst。

### rofi

应用启动器与通用菜单（dmenu 替代）。

- **包**：官方仓库 `rofi`；AUR `rofi-power-menu`
- **部署**：
  - `files/rofi/config.rasi` → `~/.config/rofi/config.rasi`
  - `catppuccin-default.rasi`、`catppuccin-mocha.rasi`、`custom.rasi` → `~/.local/share/rofi/themes/`
- **要点**：`Super+D` 应用启动、`Super+E` emoji、`Super+0` 电源菜单、`Super+O` 剪贴板历史、`Super+N` 笔记 picker，全都走 rofi。

### satty

截图标注工具。

- **包**：官方仓库 `satty`、`grim`、`slurp`（截图管线）
- **部署**：`files/satty/config.toml` → `~/.config/satty/config.toml`
- **要点**：`Super+P` 区域截图后直接进入 satty 标注；标注流程见[日常使用指南](usage.md)。

### scratchpad

笔记速记（`Super+N`）。

- **包**：无独立包（bash 脚本，依赖 rofi / kitty / nvim）
- **部署**：`files/scratchpad/scratchpad.sh` → `~/.local/bin/scratchpad.sh`（0755）
- **要点**：笔记存放在 `~/.scratchpads/*.md`；picker 按修改时间倒序、显示相对时间与首行预览，`Ctrl+D` 删除（有二次确认）；编辑窗口的 class 是 `floating-scratchpad`，由 hyprland 窗口规则浮动。详细用法见[日常使用指南](usage.md)。

### pyprland

Hyprland scratchpad 守护进程，把 DeepSeek / Kimi / 微信管理成便签窗口：按呼出键从屏幕顶部滑出，再按一次滑回隐藏（键位见[日常使用指南](usage.md)）。

- **包**：AUR `pyprland`
- **部署**：
  - `files/pyprland/config.toml` → `~/.config/pypr/config.toml`
  - `files/pyprland/wechat-toggle.sh` → `~/.local/bin/wechat-toggle.sh`（0755）
- **要点**：hyprland 启动时拉起 `pypr` 守护进程，呼出键实际调用 `pypr toggle <名字>`。窗口隐藏期间常驻不关闭，从 rofi 启动也会被按 class 接管。DeepSeek/Kimi 懒启动（首次呼出才拉起）；微信未运行时 `Alt+W` 直接启动（wechat-toggle.sh 只在窗口存在时才调 pypr）。
- **注意**：
  - DeepSeek/Kimi 的 `process_tracking = false` 不可改回——Chrome `--app` 窗口归属已运行的浏览器进程，PID 跟踪会失效。
  - 微信的 `command = ""`、`pinned = false`、`size = ""` 是一组绑定约束：登录窗会被主窗替换、窗口由微信自行重建，pypr 只能按 class 匹配，不能 pin 也不能改尺寸。
  - 不要给这三个窗口的 hyprland 规则加 `workspace = "special:..."`——pypr 是把窗口移到当前工作区显示的；special workspace 上 fcitx5 候选框不渲染。

## Shell 与终端

### zsh

默认 shell 及整套终端体验的核心。

- **包**：官方仓库 `zsh`、`zsh-syntax-highlighting`
- **部署**：
  - oh-my-zsh（git clone，不自动更新）→ `~/.oh-my-zsh`
  - `files/zsh/zshrc` → `~/.zshrc`（`force: false`：只部署一次，之后归用户所有）
  - `files/zsh/` 下 15 个编号 fragment（`[0-9]*.zsh`）→ `~/.config/zsh/conf.d/`
  - `catppuccin_mocha-zsh-syntax-highlighting.zsh` → `~/.local/share/`
- **要点**：`.zshrc` 只是骨架，按字典序 source `~/.config/zsh/conf.d/*.zsh`；fragment 编号 05–99，`99-syntax-highlighting.zsh` 必须保持最后。playbook 会检查已有 `.zshrc` 是否保留 conf.d 循环，缺失则警告。
- **注意**：重写 `.zshrc` 时务必保留 conf.d sourcing 循环，否则所有 app 的 shell 集成静默失效。

### kitty

终端模拟器。

- **包**：官方仓库 `kitty`
- **部署**：`files/kitty/`（`kitty.conf`、`Catppuccin-Mocha.conf`）→ `~/.config/kitty/`
- **要点**：`40-kitty.zsh` fragment 提供 shell 集成。

### atuin

shell 历史记录（SQLite 存储 + 模糊搜索）。

- **包**：官方仓库 `atuin`
- **部署**：
  - `files/atuin/config.toml` → `~/.config/atuin/config.toml`
  - `files/atuin/catppuccin-mocha-blue.toml` → `~/.config/atuin/themes/catppuccin-mocha-blue.toml`
- **要点**：`80-atuin.zsh` fragment 注入 `atuin init`。

### direnv

按目录自动加载/卸载环境变量（进入目录生效 `.envrc`）。

- **包**：官方仓库 `direnv`
- **部署**：`files/direnv/direnvrc` → `~/.config/direnv/direnvrc`
- **要点**：`70-direnv.zsh` fragment 挂上 shell hook。

### try-cli

`try` 命令——在带日期的隔离目录里做实验（tobi/try，Ruby 实现）。

- **包**：无独立包（`ruby` 在编程语言组）
- **部署**：
  - git clone `tobi/try` → `~/.local/share/try-cli`（不自动更新）
  - `files/try-cli/try`（wrapper，exec ruby 跑 clone 里的 `try.rb`）→ `~/.local/bin/try`
- **要点**：`60-try.zsh` fragment 执行 `try init ~/src/tries`。
- **注意**：AUR 里有个同名的 `try` 包，是另一个工具——不要安装它来替换。

## 输入法与中文环境

### fcitx5

输入法框架，搭配 rime 引擎与雾凇拼音词库。

- **包**：官方仓库 `fcitx5`、`fcitx5-gtk`、`fcitx5-qt`、`fcitx5-configtool`、`fcitx5-rime`；AUR `rime-ice-git`
- **部署**：
  - `classicui.conf`、`rime.conf` → `~/.config/fcitx5/conf/`
  - `profile` → `~/.config/fcitx5/profile`（`backup: true`：fcitx5 运行时改动输入法列表会重写它）
  - `default.custom.yaml` → `~/.local/share/fcitx5/rime/default.custom.yaml`
- **要点**：catppuccin 皮肤由 settings 角色部署；日常用法见[日常使用指南](usage.md)。用户词频数据在 `~/.local/share/fcitx5/rime/*.userdb`，换机时可从旧系统拷贝保留。

## AI 工具

### deepseek

DeepSeek 聊天网页应用（Chrome `--app` 模式，独立窗口）。

- **包**：无独立包（依赖 AUR `google-chrome`）
- **部署**：
  - `files/deepseek/deepseek.desktop` → `~/.local/share/applications/`
  - `files/deepseek/deepseek.png` → `~/.local/share/icons/hicolor/256x256/apps/`
- **要点**：`Super+Q` 呼出/隐藏（pyprland scratchpad，见 [pyprland](#pyprland)）。DeepSeek 的 CLI（dsh）见 [dsh-web](#dsh-web)。

### kimi

Kimi 网页应用（Chrome `--app` 模式）。

- **包**：AUR `kimi-code`（Kimi CLI）；桌面项依赖 `google-chrome`
- **部署**：`files/kimi/kimi.desktop` + `kimi.png`（路径模式同 deepseek）
- **要点**：``Super+` `` 呼出/隐藏（pyprland scratchpad）。

### pi

pi coding agent（`@mariozechner/pi-coding-agent`）。

- **包**：npm 全局（由 dev app 安装）
- **部署**：`files/pi/settings.json` → `~/.pi/agent/settings.json`

### dsh-web

DeepSeek Harness 的浏览器 UI（`dsh web`，监听 127.0.0.1:3080），登录后自启动。

- **包**：npm 全局 `@deepseek-ai/dsh`（由 dev app 安装到 `~/.local/bin/dsh`）
- **部署**：`files/dsh-web/dsh-web.service` → `~/.config/systemd/user/dsh-web.service`（由 services 角色 enable）
- **要点**：`systemctl --user status dsh-web` 查状态；API key 放 `~/.dsh/.env`；改端口、升级、端口占用处理等详见 README 的 dsh web 一节。
- **注意**：只跑 `--tags dsh-web` 时 unit 只部署不 enable，需要手动 `systemctl --user enable --now dsh-web` 一次。

## 开发工具

### git

- **包**：官方仓库 `git`、`git-delta`、`lazygit`
- **部署**：`files/git/`（`custom`、`catppuccin.gitconfig`）→ `~/.config/git/`
- **要点**：`~/.config/git/config` 归用户所有——首次运行时 playbook 交互式询问 `user.name` / `user.email`，之后永不覆盖；它 include 了 playbook 管理的 `~/.config/git/custom`（delta pager + catppuccin 主题）。
- **注意**：不要手改 `custom`；如果 `config` 缺了对 `custom` 的 include，playbook 会警告。

### github

GitHub 网页应用（Chrome `--app` 模式）。

- **包**：无独立包（依赖 `google-chrome`）
- **部署**：`files/github/github.desktop` + `github.png`（路径模式同 deepseek）

### dev

开发工具链与环境初始化（无配置文件）。

- **包**：官方仓库的 Programming languages 组（`rustup`、`python`、`ruby`、`nodejs`、`bun`、`pnpm`、`go`、`mise` 等）、CLI tools 组（`fzf`、`zoxide`、`ripgrep`、`yazi` 等）、LSP / Development 组（`lua-language-server`、`pyright`、`ruff`、`gopls` 等）；AUR 的 Dev tools 组（`terraform-ls`、`vscode-langservers-extracted`、`prettierd`、`vagrant`、`pitchfork-bin`）与 AI coding tools 组（`claude-code`、`opencode-bin`、`herdr-bin`）
- **部署**：无 `files/` 目录；任务做环境初始化：
  - npm 全局前缀设为 `~/.local`，安装 npm 全局工具（`@openai/codex`、`@mariozechner/pi-coding-agent`、`@deepseek-ai/dsh`）
  - `rustup default stable`
  - 创建工作目录 `~/Projects`、`~/Pictures/mpv`、`~/src/tries`
  - `bat cache --build`（让 bat 识别 catppuccin 主题）
- **注意**：`claude-code` 走 AUR 而不是 npm 全局（原生二进制需要 postinstall 下载）。

### nvim

编辑器，LazyVim 发行配置。

- **包**：官方仓库 `neovim`、`tree-sitter-cli`（LSP 服务器见 dev 一节，`_pacman.yml` 的 `LSP / Development` 组）
- **部署**：`files/nvim/` 整棵树 → `~/.config/nvim/`（LazyVim starter；首次启动由 lazy.nvim 自动装插件、编译 tree-sitter 语法）
- **注意**：`files/nvim/` 是唯一保留内部目录结构的 `files/` 目录（整体部署），其他 app 的 `files/` 都是扁平的。

### zed

- **包**：官方仓库 `zed`（如不顺手可换 AUR `zed-preview-bin`）
- **部署**：`files/zed/settings.json` → `~/.config/zed/settings.json`（`backup: true`：Zed 会从 UI 改写设置）

### k3s

常驻单节点 Kubernetes 集群。

- **包**：AUR `k3s-bin`；官方仓库 `kubectl`、`helm`、`k9s`
- **部署**：`files/k3s/config.yaml` → `/etc/rancher/k3s/config.yaml`（root 所有，内容是 `write-kubeconfig-mode: "644"`）
- **要点**：`k3s.service` 由 services 角色 enable；`25-k3s.zsh` fragment 设 `KUBECONFIG=/etc/rancher/k3s/k3s.yaml`，用户直接用 `kubectl` 无需拷贝证书。software 角色先于 services 运行，所以配置在 k3s 首次启动前就位，生成的 kubeconfig 从一开始就是 644。

## 日常应用

### wechat

微信 Linux 版。

- **包**：AUR `wechat-bin`
- **部署**：`templates/wechat/wechat.desktop.j2` → `~/.local/share/applications/wechat.desktop`（用户级覆盖，掌握启动参数）
- **要点**：`Alt+W` 呼出/隐藏（pyprland scratchpad）；微信未运行时 `Alt+W` 直接启动。
- **注意**：wechat ≥ 4.1.13 原生支持 Wayland，分数缩放由 compositor 驱动——绝不能往桌面项里加 `QT_SCALE_FACTOR`，会双重缩放导致界面空白、点击错位。

### gmail

Gmail 网页应用 + 系统级 `mailto:` 处理器。

- **包**：无独立包（依赖 `google-chrome`；脚本依赖 `python`）
- **部署**：
  - `templates/gmail/gmail.desktop.j2` → `~/.local/share/applications/gmail.desktop`（注册为 `x-scheme-handler/mailto`）
  - `files/gmail/gmail-mailto`（Python 脚本）→ `~/.local/bin/gmail-mailto`（0755）
  - `files/gmail/gmail.png` → 图标目录
- **要点**：点击任何 `mailto:` 链接会进到脚本：解析收件人/主题/正文/抄送后，用 Chrome `--app` 打开 Gmail 写信界面；不带参数则打开收件箱。

### mpv

视频播放器。

- **包**：官方仓库 `mpv`、`mpv-mpris`；AUR `mpv-uosc`、`mpv-thumbfast-git`
- **部署**：
  - `files/mpv/`（`mpv.conf`、`input.conf`、`catppuccin-mocha-blue.conf`）→ `~/.config/mpv/`
  - uosc 脚本符号链接 → `~/.config/mpv/scripts/uosc`
  - uosc 图标字体符号链接 → `~/.config/mpv/fonts/`
- **要点**：uosc 的图标靠字体连字渲染，而 mpv 只扫描自己配置目录下的 `fonts/`，所以把包里的字体链接进来。

### zathura

PDF 阅读器（vim 键位）。

- **包**：官方仓库 `zathura`、`zathura-pdf-mupdf`
- **部署**：`files/zathura/`（`zathurarc`、`catppuccin-mocha` 主题）→ `~/.config/zathura/`

### pcmanfm

文件管理器（`Super+F3`）。

- **包**：官方仓库 `pcmanfm`（`gvfs` 提供挂载/回收站支持）
- **部署**：`files/pcmanfm/pcmanfm.conf` → `~/.config/pcmanfm/default/pcmanfm.conf`（`backup: true`：pcmanfm 退出时会写状态）

### mimeapps

MIME 类型默认应用关联（不是软件，是一份配置）。

- **包**：无
- **部署**：`files/mimeapps/mimeapps.list` → `~/.config/mimeapps.list`（`backup: true`：`xdg-mime` 命令改默认应用时会重写它）

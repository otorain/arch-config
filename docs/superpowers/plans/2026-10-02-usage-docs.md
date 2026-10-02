# Chinese Usage Documentation Set — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write a five-file Chinese documentation set under `docs/` (usage guide, per-app notes, maintenance, architecture, index) and link it from the bilingual READMEs.

**Architecture:** Pure Markdown, no code changes. One task per document, executed in dependency order (apps.md first because other docs link to its per-app anchors; the index last once all targets exist). Each task ends with mechanical verification (path existence, heading counts, anchor resolution) and a commit.

**Tech Stack:** Markdown (GitHub-flavored), bash grep loops for verification.

**Spec:** `docs/superpowers/specs/2026-10-02-usage-docs-design.md`

## Global Constraints

- 正文全部中文；文件名 ASCII kebab-case；专名（Hyprland、waybar、catppuccin、fcitx5 等）保留英文不翻译。
- 用户可见 UI 文本（桌面项名称、waybar 标签、hyprlock 占位符）按仓库原文引用（它们是中文）。
- 不修改 `playbooks/` 下任何文件。
- 数字以仓库实际为准：app 31 个、zsh fragment 15 个、模板 3 个。
- 跨文档链接只链接 ASCII 标题锚点（apps.md 的 `### <app名>`）；中文标题的锚点不做跨文档链接目标。
- 提交信息用英文，结尾加 `Co-Authored-By: Claude Code <noreply@anthropic.com>`。
- 文档面向"使用/维护这台机器的用户"视角，不是 agent 视角；AGENTS.md 的 Gotchas 是事实来源，不是复制对象。

## Review Focus

1. **数字漂移** — README.md Features 行写 "30 apps"，同文件 Layout 节写 31，真实值 31（`main.yml` 中 31 个 `App:` include）。文档若照抄会传播错误。→ Task 1 Step 4 的计数检查钉住 31；Task 6 Step 3 修正 README 双语数字。
2. **虚构仓库路径** — 文档引用 `playbooks/...` 路径时凭记忆写错（如 `files/zsh/` 下的真实文件名）。→ 每个 Task 验证步里的路径存在性循环。
3. **断锚点** — 跨文档链接 `apps.md#waybar` 若目标标题不存在，GitHub 静默跳到页首。→ Task 2/3/4/5 验证步里的锚点解析循环。
4. **与 AGENTS.md Gotchas 说反** — 高风险条目：wechat `QT_SCALE_FACTOR`（绝不能建议重新加回）、waybar 0.15.0 工作区点击切换（不要"修"）、hypridle 的 dpms 写法、popup 不要加 window_rules。→ Task 3 Step 2、Task 4 Step 2 的逐条对照核对。
5. **写成 agent 视角** — 照抄 AGENTS.md 祈使句（"Do NOT run stylua..."）而不是向用户解释。→ Task 1–4 各自的用户视角通读步。

---

### Task 1: docs/apps.md（31 个 app 逐个说明）

**Files:**
- Create: `docs/apps.md`
- Read: `playbooks/roles/software/tasks/main.yml`、`tasks/_pacman.yml`、`tasks/_aur.yml`、全部 `tasks/<app>.yml`、`ls files/<app>/`、`templates/<app>/`

**Interfaces:**
- Produces: `docs/apps.md`，其中每个 app 一个 `### <app名>` 标题（名字与 `main.yml` 的 include 完全一致：`atuin`、`deepseek`、`dev`、`direnv`、`dsh-web`、`dunst`、`fcitx5`、`git`、`github`、`gmail`、`hypridle`、`hyprland`、`hyprlock`、`hyprpaper`、`kimi`、`k3s`、`kitty`、`mimeapps`、`mpv`、`nvim`、`pcmanfm`、`pi`、`rofi`、`satty`、`scratchpad`、`try-cli`、`waybar`、`wechat`、`zathura`、`zed`、`zsh`）。后续 Task 2/3/4 用 `apps.md#<app名>` 链接这些锚点。

- [ ] **Step 1: 提取事实**

完整阅读 `tasks/_pacman.yml` 和 `tasks/_aur.yml`，从 `# ===` 分组注释建立 app → 包映射（一个 app 可能对应多个包；`dev`、`hyprland` 这类无 `files/` 目录的也要查到包归属）。然后对每个 app：读 `tasks/<app>.yml`，记录每个 `copy`/`template` 任务的 `src` → `dest`、`force: false`、`become: true`、`mode`、部署的 systemd unit、以及任何非常规任务（git clone、命令、warn 对）。`templates/` 下三个模板（hyprland/hyprland.lua.j2、waybar/config.jsonc.j2、wechat/wechat.desktop.j2）记入对应 app。

- [ ] **Step 2: 写 docs/apps.md**

固定骨架（类别与 app 归属不允许改动）：

```markdown
# 应用说明

> 31 个 app，按类别分组。每个 app 一节：装了什么包、部署了哪些文件、使用要点与注意事项。
> 包清单见 `playbooks/roles/software/tasks/_pacman.yml`（官方仓库）与 `_aur.yml`（AUR）。

## 桌面组件
### hyprland
### hypridle
### hyprlock
### hyprpaper
### waybar
### dunst
### rofi
### satty
### scratchpad

## Shell 与终端
### zsh
### kitty
### atuin
### direnv
### try-cli

## 输入法与中文环境
### fcitx5

## AI 工具
### deepseek
### kimi
### pi
### dsh-web

## 开发工具
### git
### github
### dev
### nvim
### zed
### k3s

## 日常应用
### wechat
### gmail
### mpv
### zathura
### pcmanfm
### mimeapps
```

每个 app 节的正文模板（按需省略"要点/注意"，但"包"和"部署"必须有；`dev`、`hyprland` 无 `files/` 目录的写"仅包，无配置文件"）：

```markdown
### waybar

状态栏。

- **包**：官方仓库 `waybar`
- **部署**：
  - `templates/waybar/config.jsonc.j2` → `~/.config/waybar/config.jsonc`（模板，消费 host_vars 的 `net_interface`）
  - `files/waybar/style.css` → `~/.config/waybar/style.css`
  - `files/waybar/weather.py`、`calendar.py`、`waybar_geom.py` → `~/.config/waybar/`
- **要点**：天气/日历弹层见 [日常使用指南](usage.md#waybar-状态栏)；机制见 [架构与原理](architecture.md)。
- **注意**：0.15.0 的工作区点击切换失效是已知上游问题，0.16 修复，不要用配置绕过。
```

（上述 waybar 节是格式示例， executor 需按 Step 1 提取的真实事实写全部 31 节；usage.md / architecture.md 此刻不存在，链接目标在后续任务创建，属预期。）

- [ ] **Step 3: 用户视角通读**

通读全文一遍：每节是否回答了"这是什么、装了什么、放到哪了、我要注意什么"？删除任何 agent 视角的祈使句痕迹。

- [ ] **Step 4: 验证（计数 + 路径）**

```bash
cd /home/ian/data/project/arch-config
# 31 个 app 节一个不缺、一个不多
grep -oP 'name: "App: \K[a-z0-9-]+' playbooks/roles/software/tasks/main.yml | while read -r app; do
  grep -q "^### $app\$" docs/apps.md || echo "MISSING app section: $app"
done
test "$(grep -cE '^### [a-z0-9-]+$' docs/apps.md)" = "31" || echo "app heading count != 31"
# 文中引用的仓库路径全部真实存在
grep -oE '(playbooks|assets)/[A-Za-z0-9_./-]+' docs/apps.md | sort -u | while read -r p; do
  [ -e "$p" ] || echo "MISSING path: $p"
done
```

Expected: 无输出。

- [ ] **Step 5: Commit**

```bash
cd /home/ian/data/project/arch-config
git add docs/apps.md
git commit -m "docs: add per-app documentation (docs/apps.md)

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 2: docs/usage.md（日常使用指南）

**Files:**
- Create: `docs/usage.md`
- Read: `playbooks/roles/software/templates/hyprland/hyprland.lua.j2`、`templates/waybar/config.jsonc.j2`、`files/waybar/{weather,calendar,waybar_geom}.py`、`files/scratchpad/scratchpad.sh`、`files/satty/`、`tasks/fcitx5.yml`、`ls files/fcitx5/`、README.md Keybindings 表

**Interfaces:**
- Consumes: `docs/apps.md` 的 `### <app名>` 锚点（Task 1）。
- Produces: `docs/usage.md`，含 `## waybar 状态栏` 等场景节（中文标题，仅本文内部锚点互链）。

- [ ] **Step 1: 提取事实**

从 `hyprland.lua.j2` 提取全部 `hl.bind`（已在 plan 调研中确认位于 171–404 行），按场景归类；从 `config.jsonc.j2` 提取 waybar 模块清单及每个模块的 `on-click`/`tooltip` 行为；从 `weather.py`/`calendar.py` 提取弹层的打开方式与关闭方式（点击外部关闭、再次点击模块切换）；从 `scratchpad.sh` 提取笔记 scratchpad 的交互（picker 排序、预览、`Ctrl+D` 删除——与 git log `461dba0` 一致）；从 `tasks/fcitx5.yml` + `files/fcitx5/` 提取输入法配置部署内容。

- [ ] **Step 2: 写 docs/usage.md**

固定骨架：

```markdown
# 日常使用指南

> 面向已经装好系统的日常使用。README 有快捷键速查总表；本篇按场景讲解机制与用法。

## 快捷键按场景
### 启动应用
### 窗口管理
### 工作区
### 截图与取色
### 剪贴板
### 系统控制

## waybar 状态栏
## 输入法（fcitx5 + rime-ice）
## 截图工作流
## 剪贴板历史
## 笔记 scratchpad
```

内容要求（写到点，不注水）：

- **启动应用**：`Super+D` rofi、终端、浏览器等；提及 rofi 还有 emoji（`Super+E`）和 power-menu（`Super+0`）模式。
- **窗口管理**：焦点/移动/浮动/全屏/tab group（`Super+W`）/dwindle preselect（`Super+Shift+V`、`Super+;`）/dwindle↔scrolling 切换（`Super+Shift+S`）；`Super+R` resize 子模式的进入与退出（H/J/K/L 调整，Enter/Esc 退出）；`Super+=`/`-` 直接微调。
- **工作区**：1–9 切换与移动、`Alt+Tab` 回上一个工作区、滚轮切换；special workspace 机制——`Super+Q`（DeepSeek）与 ``Super+` ``（Kimi）是 `workspace.toggle_special`，窗口常驻、按一次呼出再按一次隐藏，链接 `apps.md#deepseek` / `apps.md#kimi`。
- **截图与取色**：三种截图的分工（`Super+P` 区域+satty 标注、`Print` 全屏存盘、`Shift+Print` 区域存盘），保存路径 `~/Pictures/screenshot-*.png`；`Super+Shift+P` hyprpicker 取色自动复制。
- **剪贴板**：`Super+C/V/X` 的 terminal-aware 实现原理（hyprland.lua.j2 中按窗口 class 决定发 `Ctrl+Shift+C` 还是 `Ctrl+C`，代码在 227–246 行的 `send_shortcut_once`）；`Super+O` cliphist 历史。
- **系统控制**：锁屏（hypridle → hyprlock 链条）、`Super+M` 显隐 waybar（SIGUSR1）、`Super+Shift+D` 重启 dunst、`Super+Shift+C` reload 配置、音量/亮度/播放键（`locked = true` 表示锁屏下也可用）。
- **waybar 状态栏**：逐个模块说明；天气弹层（`weather.py --popup`）与日历来层（`calendar.py`）是 gtk4-layer-shell 全屏透明 surface：点击模块打开、点击外部或再点模块关闭，锚定在模块正下方；`Super+M` 整体显隐。链接 `apps.md#waybar`。
- **输入法**：切换键、rime-ice 雾凇拼音、候选词/用户词库位置 `~/.local/share/fcitx5/rime/*.userdb`（迁移旧词频数据的方法，与 README post-install 一致）；皮肤来自 settings 角色的 catppuccin 主题。
- **笔记 scratchpad**：`Super+N` 打开 rofi picker（按修改时间排序、带预览、显示相对时间、`Ctrl+D` 删除），选中后浮动 nvim 编辑；笔记目录位置从 `scratchpad.sh` 实际读取。

- [ ] **Step 3: 用户视角通读**

找一个"刚装好系统第一次用"的读者视角通读：每个场景是否能照着做？键位与 `hyprland.lua.j2` 实际绑定抽查 10 个确认无误。

- [ ] **Step 4: 验证（键位抽查 + 锚点 + 路径）**

```bash
cd /home/ian/data/project/arch-config
# 文中链接的 apps.md#<app> 锚点全部存在
grep -oE '\]\(apps\.md#[a-z0-9-]+\)' docs/usage.md | sed 's/](apps.md#//; s/)//' | sort -u | while read -r a; do
  grep -q "^### $a\$" docs/apps.md || echo "MISSING anchor in apps.md: $a"
done
# 文中引用的仓库路径全部真实存在
grep -oE '(playbooks|assets)/[A-Za-z0-9_./-]+' docs/usage.md | sort -u | while read -r p; do
  [ -e "$p" ] || echo "MISSING path: $p"
done
# 键位事实抽查：文中提到的绑定必须能在模板中找到（示例三个，撰写时自定共 10 个）
grep -q 'toggle_special("deepseek")' playbooks/roles/software/templates/hyprland/hyprland.lua.j2 || echo "FACT: deepseek special workspace"
grep -q 'hl.dsp.submap("resize")' playbooks/roles/software/templates/hyprland/hyprland.lua.j2 || echo "FACT: resize submap"
grep -q 'SIGUSR1 waybar' playbooks/roles/software/templates/hyprland/hyprland.lua.j2 || echo "FACT: waybar toggle"
```

Expected: 无输出。

- [ ] **Step 5: Commit**

```bash
cd /home/ian/data/project/arch-config
git add docs/usage.md
git commit -m "docs: add daily usage guide (docs/usage.md)

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 3: docs/maintenance.md（维护与开发）

**Files:**
- Create: `docs/maintenance.md`
- Read: `AGENTS.md`（Verification / Gotchas 节）、`playbooks/roles/software/tasks/main.yml` 头部注释、`tasks/_aur.yml`、`tasks/yay.yml`、`tasks/try-cli.yml`、`inventory/hosts.ini`、`inventory/host_vars/desktop.yml`

**Interfaces:**
- Consumes: `docs/apps.md` 的 `### <app名>` 锚点。
- Produces: `docs/maintenance.md`。

- [ ] **Step 1: 提取事实**

确认以下事实点并记录准确表述：`main.yml` 头部关于 `apply: tags:` + 外层 `tags:` 的注释（1–10 行）；`_aur.yml` 的 warn-and-continue 与 stderr tail 打印、`aur_builder` 用户创建；`yay.yml` 的 bootstrap 依赖（base-devel + git）；zsh fragment 的 fileglob 部署（`zsh/[0-9]*.zsh`）；`try-cli.yml` 的 git clone 安装方式。

- [ ] **Step 2: 写 docs/maintenance.md 并逐条对照 AGENTS.md Gotchas**

固定骨架：

```markdown
# 维护与开发

> 如何安全地修改这套配置。静态检查与运行方式也见 AGENTS.md；本篇是用户视角的操作手册。

## 运行 playbook
## 修改配置的正确姿势
## 添加一个软件
## 删除一个软件
## 新增一台机器
## 验证
## 常见坑
```

内容要求：

- **运行 playbook**：全量 / `--tags <app>` / 多标签逗号分隔 / `--list-tasks` / `--check` dry run / `--ask-become-pass` 的原因；幂等性（重跑安全，只读探针 `check_mode: false` 的含义一句话）。
- **修改配置的正确姿势**：改 `roles/**/files/` 后用 playbook 部署，绝不手工复制进 `$HOME`；hyprland/waybar/wechat 三个是模板——改模板或 host_vars，不改 `~/.config` 下的渲染产物（下次运行会被覆盖）；`.zshrc` 与 `~/.config/git/config` 是例外（`force: false`，部署一次后归用户）。
- **添加一个软件**：决策树——官方仓库包进 `_pacman.yml` 对应 `# ===` 分组，AUR 包进 `_aur.yml`（自带失败继续）；然后 `files/<app>/`（扁平、无子目录镜像）+ `tasks/<app>.yml` + `main.yml` 按字母序加 include（`apply: tags:` + 外层 `tags:` 双写，附 4 行示例）；需要 shell 集成时在 `files/zsh/` 加编号 fragment（05–99，避开已占号：05/10/12/15/20/25/30/40/50/60/65/70/80/90/99，99 必须保持最后）。
- **删除一个软件**：删 `files/<sw>/` + `tasks/<sw>.yml` + `main.yml` 中 include；若包也要卸载，从 `_pacman.yml`/`_aur.yml` 移除条目（playbook 不负责卸载，需手动 `pacman -Rs`）。
- **新增一台机器**：`hosts.ini` 加别名（本机跑用 `ansible_connection=local`）+ `host_vars/<name>.yml` 三个变量（`monitor`、`scale`、`net_interface`）+ `ansible-playbook site.yml -l <name>`；`hyprctl monitors` 查显示器名。
- **验证**：`ansible-playbook site.yml --syntax-check`、`ansible-lint`、`--check`、渲染产物 `luac -p ~/.config/hypr/hyprland.lua`；明确**不要**对 `.j2` 模板跑 stylua。
- **常见坑**（用户视角，每条给出"现象 → 原因 → 怎么办"）：AUR 包失败 warn-and-continue 看 stderr tail；`aur_builder` 是什么（NOPASSWD 仅限 `/usr/bin/pacman`，登录用户 sudo 不受影响）；wechat 不要加 `QT_SCALE_FACTOR`（≥4.1.13 原生 Wayland 分数缩放，加了会双重缩放）；waybar 0.15.0 工作区点击切换失效是上游已知问题（0.16 修复，不要绕过）；gsettings 在 tty/headless 下只警告不失败是预期；`try` 命令来自 `~/.local/bin/try`（tobi/try 的 clone），AUR 的 `try` 是另一个工具。

写完后逐条对照 AGENTS.md 的 Gotchas：本篇涉及的每一条（aur_builder、QT_SCALE_FACTOR、waybar 点击、stylua、try、zshrc）表述必须与 AGENTS.md 一致，发现不一致立即修正。

- [ ] **Step 3: 用户视角通读**

以"我想加一个自己常用的软件"为情景走一遍流程步骤，确认可照着执行、无缺失环节（包 → files → task → include → 部署 → 验证）。

- [ ] **Step 4: 验证（锚点 + 路径 + 编号事实）**

```bash
cd /home/ian/data/project/arch-config
grep -oE '\]\(apps\.md#[a-z0-9-]+\)' docs/maintenance.md | sed 's/](apps.md#//; s/)//' | sort -u | while read -r a; do
  grep -q "^### $a\$" docs/apps.md || echo "MISSING anchor in apps.md: $a"
done
grep -oE '(playbooks|assets)/[A-Za-z0-9_./-]+' docs/maintenance.md | sort -u | while read -r p; do
  [ -e "$p" ] || echo "MISSING path: $p"
done
# zsh 编号事实：文中若列已占编号，与实际文件一致
ls playbooks/roles/software/files/zsh/ | grep -oP '^[0-9]+' | sort -n | tr '\n' ' '
```

Expected: 前两个循环无输出；最后一条输出实际编号列表，与文中一致。

- [ ] **Step 5: Commit**

```bash
cd /home/ian/data/project/arch-config
git add docs/maintenance.md
git commit -m "docs: add maintenance and development guide (docs/maintenance.md)

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 4: docs/architecture.md（架构与原理）

**Files:**
- Create: `docs/architecture.md`
- Read: `AGENTS.md` 全文、`playbooks/site.yml`、`playbooks/roles/base/tasks/main.yml`、`playbooks/roles/settings/tasks/main.yml`、`playbooks/roles/services/tasks/main.yml`、`inventory/group_vars/all.yml`、`files/waybar/weather.py` 头部（LD_PRELOAD re-exec 块）、`tasks/git.yml`

**Interfaces:**
- Consumes: `docs/apps.md` 的 `### <app名>` 锚点。
- Produces: `docs/architecture.md`。

- [ ] **Step 1: 提取事实**

读四个角色的 tasks/main.yml，确认各自职责清单（base：preflight、timezone、locale、zram、sshd、user-dirs；settings：fcitx5 主题、GTK/Qt/Kvantum/字体、GTK4 符号链接、gsettings、SDDM；services：用户组、默认 shell、system units、user units、dsh-web 服务）；确认 `group_vars/all.yml` 的 `system_units`/`user_units`/`npm_globals` 清单；确认 `weather.py` 的 `LD_PRELOAD` re-exec 块原文；确认 `tasks/git.yml` 的 config/custom 所有权分工。

- [ ] **Step 2: 写 docs/architecture.md 并逐条对照 AGENTS.md Gotchas**

固定骨架：

```markdown
# 架构与原理

> 概念讲解：这套配置为什么是这样组织的。不含操作步骤（操作见 [维护与开发](maintenance.md)）。

## 总览：一个 playbook，四个角色
## 角色分层与顺序
## 软件清单与配置分离
## aur_builder：无 tty 的 AUR 安装
## 模板渲染流：host_vars → jinja2 → ~/.config
## zsh：skeleton + conf.d
## git 配置的所有权模型
## 主题体系：catppuccin-mocha 贯穿一切
## 弹层机制：gtk4-layer-shell
## 命名冲突：try
```

内容要求（每节 100–300 字，讲清"为什么"，引用真实文件路径）：

- **总览**：`site.yml` 单入口，`hosts: desktop`，角色 `base → software → settings → services`；幂等。
- **角色分层与顺序**：各角色职责（Step 1 清单）；顺序原因——services 的用户组/默认 shell 依赖 software 装的包，所以不能在 base；settings 的主题配置依赖软件就位。
- **软件清单与配置分离**：所有官方包在 `_pacman.yml`、所有 AUR 在 `_aur.yml`，`<app>.yml` 只部署配置/用户服务/zsh fragment；基础设施硬顺序 `_pacman → yay → _aur`（yay 需要 base-devel+git，`_aur` 需要 yay 二进制）；`_aur_one.yml` 是单包 helper。
- **aur_builder**：makepkg 拒绝 root；无 tty 时 yay 内部的 `sudo pacman -U` 无法询问密码 → 专用系统用户 + 显式 `HOME=/home/aur_builder`（Ansible sudo 不传 `-H`）+ sudoers 只放行 `/usr/bin/pacman`（kewlfft.aur 模式），登录用户 sudo 仍然全程要密码。
- **模板渲染流**：三个模板（hyprland.lua、waybar config、wechat desktop）消费 `host_vars/desktop.yml` 三变量；渲染产物直接改会被覆盖，所以机器差异永远改 host_vars；`luac -p` 只对渲染产物有意义。
- **zsh**：`.zshrc` 骨架只负责 source `~/.config/zsh/conf.d/*.zsh`（`force: false` 部署一次，之后归用户；grep+warn 守护）；15 个编号 fragment 字典序加载，99 语法高亮必须最后。
- **git 配置**：`~/.config/git/config` 用户所有（首次运行交互问 name/email，永不覆盖），include 管理的 `~/.config/git/custom`（delta + catppuccin，别手改）。
- **主题体系**：catppuccin-mocha 蓝 accent 如何落到 GTK（Colloid-Dark-Catppuccin）、Qt/Kvantum、fcitx5 皮肤、delta、zsh 语法高亮、SDDM；新配置默认跟随。
- **弹层机制**：天气/日历是 gtk4-layer-shell 全屏透明 surface；`LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so` re-exec 必须先于 libwayland-client 加载；位置/圆角/点击外部关闭都在脚本内，因此**不能**加 Hyprland window_rules、不能要 focus-out 关闭；覆盖 Colloid 主题的 CSS 需要 `GTK.STYLE_PROVIDER_PRIORITY_USER`；AT-SPI 经 `waybar_geom.py` 锚定到模块下方。链接 `apps.md#waybar`。
- **命名冲突**：`~/.local/bin/try` 是 tobi/try 的 git clone（Ruby），AUR 的 `try` 是另一个工具，不能互换。

写完后逐条对照 AGENTS.md Gotchas（弹层四条禁令、LD_PRELOAD、aur_builder、host_vars、git config、gsettings、try），表述不一致立即修正。

- [ ] **Step 3: 用户视角通读**

以"我想理解这个项目的设计"为视角通读：每节是否回答了"为什么"而不只是"是什么"？是否有任何操作步骤混入（应链接 maintenance.md 而非复制）？

- [ ] **Step 4: 验证（锚点 + 路径 + 事实抽查）**

```bash
cd /home/ian/data/project/arch-config
grep -oE '\]\((apps|usage|maintenance)\.md#[a-z0-9-]+\)|\]\((apps|usage|maintenance)\.md\)' docs/architecture.md | grep '#' | sed 's/]([a-z]*\.md#//; s/)//' | sort -u | while read -r a; do
  grep -rq "^### $a\$" docs/apps.md docs/usage.md docs/maintenance.md 2>/dev/null || echo "MISSING anchor: $a"
done
grep -oE '(playbooks|assets)/[A-Za-z0-9_./-]+' docs/architecture.md | sort -u | while read -r p; do
  [ -e "$p" ] || echo "MISSING path: $p"
done
# 事实抽查
grep -q 'aur_builder' playbooks/roles/software/tasks/_aur.yml || echo "FACT: aur_builder not in _aur.yml"
grep -q 'LD_PRELOAD' playbooks/roles/software/files/waybar/weather.py || echo "FACT: LD_PRELOAD not in weather.py"
ls playbooks/roles/software/files/zsh/[0-9]*.zsh | wc -l | grep -q '^15$' || echo "FACT: zsh fragment count != 15"
```

Expected: 无输出。

- [ ] **Step 5: Commit**

```bash
cd /home/ian/data/project/arch-config
git add docs/architecture.md
git commit -m "docs: add architecture and rationale overview (docs/architecture.md)

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 5: docs/README.md（索引）

**Files:**
- Create: `docs/README.md`

**Interfaces:**
- Consumes: 前四个文档（Task 1–4）的文件名与定位。
- Produces: `docs/README.md` — README.md / README.zh.md 链接到这里。

- [ ] **Step 1: 写 docs/README.md**

内容（短，一页以内）：

```markdown
# arch-config 使用文档

> 面向系统使用者的中文文档集。仓库概览与安装见根目录 [README.md](../README.md)。

| 文档 | 内容 | 什么时候读 |
| --- | --- | --- |
| [日常使用指南](usage.md) | 快捷键按场景、waybar 与弹层、输入法、截图、剪贴板、scratchpad | 装好系统后最先读 |
| [应用说明](apps.md) | 31 个 app 逐个：装了什么、部署到哪、注意事项 | 想知道某个软件的细节时查 |
| [维护与开发](maintenance.md) | 跑 playbook、改配置、增删软件、新增机器、验证 | 想改任何配置之前必读 |
| [架构与原理](architecture.md) | 四层角色、aur_builder、模板渲染、主题体系、弹层机制 | 想理解设计时读 |

推荐阅读路径：日常使用指南 → 应用说明（按需查阅）→ 维护与开发 → 架构与原理。
```

- [ ] **Step 2: 验证（链接目标存在）**

```bash
cd /home/ian/data/project/arch-config
for f in usage.md apps.md maintenance.md architecture.md; do
  [ -e "docs/$f" ] || echo "MISSING: docs/$f"
done
[ -e README.md ] || echo "MISSING: README.md"
```

Expected: 无输出。

- [ ] **Step 3: Commit**

```bash
cd /home/ian/data/project/arch-config
git add docs/README.md
git commit -m "docs: add docs/ index (docs/README.md)

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 6: README 双语链接 + AGENTS.md 例外 + 数字修正

**Files:**
- Modify: `README.md`（Contents 列表 + 新 Documentation 段 + "30 apps" 修正）
- Modify: `README.zh.md`（对应三处镜像）
- Modify: `AGENTS.md`（语言例外一句）

**Interfaces:**
- Consumes: `docs/README.md`（Task 5）作为链接目标。

- [ ] **Step 1: 编辑 README.md（两处插入）**

第一处——Contents 列表，在 `- [Development](#development)` 前插入：

```markdown
- [Documentation](#documentation)
```

第二处——`## Development` 段之前插入新段：

```markdown
## Documentation

系统使用文档（中文）在 [`docs/`](docs/README.md)：[日常使用指南](docs/usage.md)、
[应用说明](docs/apps.md)、[维护与开发](docs/maintenance.md)、
[架构与原理](docs/architecture.md)。
```

- [ ] **Step 2: 编辑 README.zh.md（镜像）**

读 `README.zh.md`，找到与 Step 1 对应的位置，插入中文镜像（Contents 加 `- [文档](#文档)`；对应位置加 `## 文档` 段，内容同上链接列表，引言可写"系统使用文档在 [`docs/`](docs/README.md)"）。

- [ ] **Step 3: 修正 app 数量（双语各一处）**

`README.md` Features 行 `- **30 apps** in four layers` 改为 `- **31 apps** in four layers`（真实值 31，Layout 节已写 31）。读 `README.zh.md` 找到对应行做同样修正（如 `30 个应用` → `31 个应用`，以实际行文为准）。

- [ ] **Step 4: 编辑 AGENTS.md（语言例外）**

找到 `Docs and code comments are in English.`（首个段落），改为：

```markdown
Docs and code comments are in English. Exception: the `docs/` usage
documentation set (usage / apps / maintenance / architecture) is written in
Chinese.
```

- [ ] **Step 5: 验证（链接目标 + 双语同步 + 数字）**

```bash
cd /home/ian/data/project/arch-config
for f in README.md README.zh.md; do
  grep -q 'docs/README.md' "$f" || echo "MISSING docs link in $f"
  grep -q 'docs/usage.md' "$f" || echo "MISSING usage link in $f"
done
grep -q '31 apps' README.md || echo "README.md count not fixed"
! grep -q '30 apps' README.md || echo "README.md still says 30 apps"
grep -q 'usage documentation set' AGENTS.md || echo "AGENTS.md exception missing"
# 锚点：README.md 的 #documentation 对应新标题
grep -q '^## Documentation' README.md || echo "README.md Documentation section missing"
```

Expected: 无输出（zh 版数字检查视实际行文人工确认）。

- [ ] **Step 6: Commit**

```bash
cd /home/ian/data/project/arch-config
git add README.md README.zh.md AGENTS.md
git commit -m "docs: link docs/ set from READMEs; note Chinese exception in AGENTS.md

Also fix app count in README Features: 30 → 31 (Layout section already said 31).

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Self-Review Notes

- **Spec coverage:** spec 设计 1→Task 2（usage.md）、2→Task 1（apps.md）、3→Task 3（maintenance.md）、4→Task 4（architecture.md）、5→Task 6（README 链接）、6→Task 6（AGENTS.md 例外）。索引 docs/README.md → Task 5。全覆盖。
- **Order rationale:** Task 1 先于 Task 2/3/4 因为后者链接 apps.md 的 app 锚点；Task 5 在内容文档之后；Task 6 最后（链接目标已存在，验证可通过）。
- **No placeholders:** 每个写作任务给了固定骨架 + 逐项内容要求 + 事实来源文件；验证命令完整可复制。

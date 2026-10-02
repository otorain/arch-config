# System Usage Documentation Set — Design

**Date:** 2026-10-02

## Problem

The project's only documentation is README.md (plus its Chinese mirror) — an
overview covering install, layout, a keybinding table, and one detailed app
section (dsh-web). There is no systematic documentation for **learning and
daily use**: how the desktop's pieces work (waybar popups, scratchpads, input
method), what each of the 31 apps deploys and where, how to safely modify the
project, and why the playbook is structured the way it is.

## Choices (confirmed with user)

- **Scope:** all four directions — daily usage guide, per-app notes,
  maintenance & development docs, architecture & rationale.
- **Language:** Chinese only. The user explicitly overrode the AGENTS.md
  "Docs and code comments are in English" convention for this docs set.
  README.md / README.zh.md stay bilingual as today. Filenames stay ASCII
  kebab-case.
- **Structure:** single-level `docs/` topic files (not one file per app).
  Most apps warrant only a few sentences; 31 tiny files would be
  over-engineering.

## Design

Five new files, all Chinese prose:

```
docs/
├── README.md          # 索引：每篇的定位 + 推荐阅读路径
├── usage.md           # 日常使用指南
├── apps.md            # 31 个 app 逐个说明
├── maintenance.md     # 维护与开发
└── architecture.md    # 架构与原理
```

1. **`docs/usage.md`** — 日常使用指南。按**使用场景**组织，而非键位罗列：
   - 快捷键按场景分组（启动应用 / 窗口管理 / 工作区 / 截图 / 剪贴板 /
     系统控制），讲清机制：special workspace（`Super+Q` DeepSeek、
     ``Super+` `` Kimi）是什么、`Super+R` resize 子模式如何进出、
     `Super+C/V` 的 terminal-aware 复制原理、`Super+N` 笔记 scratchpad。
   - waybar：各模块含义、天气/日历弹层（gtk4-layer-shell 全屏透明
     surface、点击外部关闭、AT-SPI 锚定 — 机制指向 architecture.md）、
     `Super+M` 显隐。
   - 输入法：fcitx5 + rime-ice 日常用法、用户词库位置与迁移。
   - 截图与剪贴板：三种截图方式的分工、cliphist 历史、satty 标注流程。
   - README 的快捷键总表保留（速查定位不变），本篇是带解释的深入版。

2. **`docs/apps.md`** — 31 个 app 按类别分组（桌面组件 / Shell 与终端 /
   输入法与中文环境 / AI 工具 / 开发工具 / 网络与服务 / 其他），每个
   app 一个小节：装了什么包（官方/AUR）、部署了哪些文件（源 → 目标
   路径）、使用要点、注意事项。内容从 `tasks/<app>.yml` 和
   `files/<app>/` 实际提取，不凭空编写。顶部放分类目录锚点。

3. **`docs/maintenance.md`** — 维护与开发，以任务为线索：
   - 运行 playbook：全量 / 单 app（`--tags`）/ `--list-tasks` / `--check`
     dry run；为什么可以安全重跑（幂等）。
   - 添加软件：`_pacman.yml` vs `_aur.yml` 的选择、`files/<app>/` 与
     `tasks/<app>.yml` 的创建、`main.yml` include 行（`apply: tags:` +
     外层 `tags:` 模式）、zsh fragment 的编号规则。
   - 删除软件三步：`files/<sw>/` + `tasks/<sw>.yml` + include 行。
   - 修改配置的正确姿势：改 `roles/**/files/` 或模板后用 playbook 部署，
     绝不手工复制；hyprland/waybar 走模板 + host_vars。
   - 新增机器：hosts.ini + host_vars 三变量。
   - 验证：syntax-check / ansible-lint / `--check` / 渲染后 `luac -p`。
   - 常见坑的用户视角版：aur_builder、wechat `QT_SCALE_FACTOR`、
     waybar 0.15.0 工作区点击切换、AUR 失败 warn-and-continue。

4. **`docs/architecture.md`** — 架构与原理（概念讲解，不含操作步骤）：
   - 四层角色 `base → software → settings → services` 及顺序原因
     （services 需要 software 装的包，groups/shell 不能在 base）。
   - 软件清单（`_pacman`/`_aur`）与配置（`<app>.yml`）分离的理由；
     基础设施 include 的硬顺序（`_pacman → yay → _aur`）。
   - `aur_builder` 用户的来龙去脉与 sudoers 边界。
   - 模板渲染流：host_vars → j2 → `~/.config`（为什么不能直接改渲染产物）。
   - zsh 的 skeleton + conf.d 模式（`force: false` 的所有权语义、
     grep+warn 保护）。
   - git config 的用户所有权模型（`config` vs `custom`）。
   - catppuccin-mocha 主题如何贯穿 GTK/Qt/Kvantum/fcitx5/delta/zsh。
   - gtk4-layer-shell 弹层的 `LD_PRELOAD` 机制与 CSS 优先级。
   - `~/.local/bin/try` 与 AUR `try` 的同名冲突。

5. **README 链接** — `README.md` 和 `README.zh.md` 各加一段（Contents
   之后），指向 `docs/` 文档集；双语同步。

6. **AGENTS.md 例外说明** — "Docs and code comments are in English" 一句
   补充例外：`docs/` 使用文档为中文。

Relationship: README 保持概览/速查定位不重组；`docs/` 是深入读物，两篇
之间用链接互通，内容不重复复制（README 已有总表的，docs 做场景化讲解）。

## Verification

- 人工通读每篇：内部链接可跳转；提到的路径/文件在仓库中真实存在；
  app 数量（31）、zsh fragment 数量（15）等数字与仓库一致。
- `README.md` / `README.zh.md` 链接双语同步。
- 不触碰 `playbooks/`，无需 ansible 检查；纯文档变更。

## Out of scope

- 不修改 playbooks 下任何代码或配置。
- 不为每个 app 单独建文件（保持 5 篇结构）。
- 不做 `docs/` 的英文版。
- 不重组 README 现有章节（只加链接段）。
- 不写软件的通用使用教程（如 "怎么用 neovim"）——只写本配置特有的
  部署位置、集成点和注意事项。

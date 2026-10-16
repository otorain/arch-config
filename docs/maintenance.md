# 维护与开发

> 如何安全地修改这套配置。静态检查与运行方式也见 AGENTS.md；本篇是用户视角的操作手册。
> 所有 ansible 命令都在 `playbooks/` 目录下运行。

## 运行 playbook

```bash
cd playbooks
ansible-playbook site.yml --ask-become-pass                # 全量
ansible-playbook site.yml --tags waybar --ask-become-pass  # 只跑一个 app
ansible-playbook site.yml --tags zsh,nvim --ask-become-pass  # 多个标签，逗号分隔
ansible-playbook site.yml --list-tasks                     # 列出所有任务与标签
ansible-playbook site.yml --check                          # dry run：只看会改什么
```

- `--ask-become-pass` 是因为部分任务需要 root（装包、写 `/etc`、启停系统服务），playbook 会现场询问 sudo 密码。
- 标签名就是 app 名（`waybar`、`zsh`、`k3s`……），另有基础设施标签 `packages`（官方仓库）、`aur`（AUR + yay）、以及四个角色标签 `base` / `software` / `settings` / `services`。
- **重跑永远安全**：所有任务幂等——已装好的包跳过、内容没变的文件不重写。任务里少数只读探测命令（如检查某文件是否存在）标了 `check_mode: false`，意思是"dry run 时也要真的跑一下"，因为后续任务要根据探测结果决定动不动手；它们本身什么都不改。

## 修改配置的正确姿势

**铁律：改仓库里的文件，然后用 playbook 部署；绝不把 `roles/**/files/` 里的文件手工复制进 `$HOME`。**

1. 改 `playbooks/roles/<role>/files/<app>/` 下的源文件（静态配置），或 `templates/<app>/` 下的模板
2. `ansible-playbook site.yml --tags <app> --ask-become-pass` 部署
3. 先用 `--check --diff` 预览改动也可以

**模板与渲染产物**：hyprland.lua、waybar config、wechat 和 gmail 的 desktop 条目这四个是模板（`templates/`），渲染后才落到 `$HOME`。直接编辑 `~/.config/hypr/hyprland.lua` 这类渲染产物没有意义——下次运行 playbook 会被覆盖。机器相关的值（显示器、缩放、网卡）永远改 `inventory/host_vars/desktop.yml`，不改模板。

**例外——部署一次后归用户所有的文件**：

- `~/.zshrc`（`force: false`）：只在新机器上部署一次骨架，之后随你改。重写时保留 source `~/.config/zsh/conf.d/*.zsh` 的循环，否则所有 app 的 shell 集成静默失效（playbook 每次运行都会检查，缺了会警告）
- `~/.config/git/config`：首次运行 git app 时交互式询问 `user.name` / `user.email` 后创建，之后永不覆盖。共享设置（delta、catppuccin）在它 include 的 `~/.config/git/custom` 里——那个是 playbook 管理的，不要手改

## 添加一个软件

以加一个名为 `myapp` 的软件为例：

1. **加包**。二选一（或都要）：
   - 官方仓库：编辑 `playbooks/roles/software/tasks/_pacman.yml`，把包名加进合适的 `# ===` 分组
   - AUR：编辑 `_aur.yml` 加进对应分组。单个 AUR 包失败只会警告并跳过（输出里带 stderr 末尾几行），不会中断整个运行
2. **放配置文件**（有的话）：新建 `playbooks/roles/software/files/myapp/`，扁平放文件——不要按目标路径建子目录镜像，目标路径只写在任务的 `dest:` 里
3. **写任务**：新建 `tasks/myapp.yml`，用 `copy`/`template` 把 `files/myapp/` 部署到 `$HOME` 下对应位置
4. **注册 include**：在 `tasks/main.yml` 里按字母序插入（注意 `tags` 要双写——外层的选中 include 本身，`apply:` 里的传给内部任务，少一个标签就到不了内层）：

   ```yaml
   - name: "App: myapp"
     ansible.builtin.include_tasks:
       file: myapp.yml
       apply:
         tags: myapp
     tags: myapp
   ```

5. **shell 集成**（可选）：在 `files/zsh/` 加一个编号 fragment（如 `35-myapp.zsh`），由 zsh app 统一 fileglob 部署。编号 05–99 之间自选，避开已占用的 05/10/12/15/20/25/30/40/50/60/65/70/80/90/99；`99-syntax-highlighting.zsh` 必须保持最后
6. **部署**：`ansible-playbook site.yml --tags myapp --ask-become-pass`

## 删除一个软件

1. 删 `playbooks/roles/software/files/<app>/` 目录
2. 删 `playbooks/roles/software/tasks/<app>.yml`
3. 删 `tasks/main.yml` 里对应的 include 块

如果包也要卸载：从 `_pacman.yml` / `_aur.yml` 移除条目——注意 playbook 只管装不管卸，已装的包要手动 `sudo pacman -Rs <pkg>`；已部署到 `$HOME` 的配置文件同样手动删除。

## 新增一台机器

1. `inventory/hosts.ini` 加一行别名；如果就在那台机器本机上跑，用 `ansible_connection=local`（和现有的 `desktop` 一样）
2. 建 `inventory/host_vars/<别名>.yml`，三个变量：

   ```yaml
   monitor: DP-1        # hyprctl monitors 查到的输出名
   scale: "1.25"        # 分数缩放；外接显示器通常用 1
   net_interface: wlp6s0  # ip link 查到的网卡名
   ```

3. 跑 `ansible-playbook site.yml -l <别名> --ask-become-pass`

模板渲染时读这些变量，所以机器差异永远只出现在 host_vars 里。

## 验证

```bash
cd playbooks
ansible-playbook site.yml --syntax-check   # 语法检查
ansible-lint                               # lint
ansible-playbook site.yml --check          # dry run
luac -p ~/.config/hypr/hyprland.lua        # 校验渲染后的 Lua 配置
```

两点提醒：

- `luac -p` 校验的是**渲染产物** `~/.config/hypr/hyprland.lua`，不是 `.j2` 模板（模板里有 jinja 语法，直接校验会误报）
- **不要**对 `hyprland.lua.j2` 跑 stylua：stylua 默认是 tab 缩进，会把整个文件重排；该文件的既有风格是 4 空格缩进加对齐的 `=`

## 常见坑

**AUR 包装不上，但 playbook 整体没失败**
现象：运行输出里某个 AUR 包显示警告和一段 stderr。
原因：`_aur.yml` 是逐包"警告并继续"的设计——AUR 包名会随时间变化，一个包失败不该拖垮整个运行。
怎么办：读警告里附的 stderr 最后 10 行；包改名的就更新 `_aur.yml` 里的条目，然后重跑 `--tags aur`。

**AUR 安装用的 `aur_builder` 是什么**
现象：进程列表或 sudoers 里冒出一个陌生用户。
原因：makepkg 拒绝以 root 构建，而 yay 安装最后一步是内部调 `sudo pacman -U`——playbook 在无 tty（脚本/CI）下跑时无法询问密码，所以 AUR 安装走一个专用系统用户 `aur_builder`。
怎么办：不用管。它的 sudoers 条目只对 `/usr/bin/pacman` 免密，其他命令一概不行；你自己用户的 sudo 仍然全程要密码。它用的是 nologin shell + 锁定密码，登录界面（SDDM）也看不到。

**微信界面空白一块、点击位置对不上**
现象：wechat 窗口部分区域空白，鼠标点击和实际响应位置错位。
原因：有人（或某次编辑）往桌面项里加了 `QT_SCALE_FACTOR`。wechat ≥ 4.1.13 原生跑 Wayland，分数缩放由 compositor 驱动，再设环境变量会双重缩放。
怎么办：确保 `~/.local/share/applications/wechat.desktop` 来自 playbook 部署（`ansible-playbook site.yml --tags wechat`），不要手加任何缩放变量。

**waybar 上点工作区编号没反应**
现象：点击状态栏的工作区数字不切换。
原因：waybar 0.15.0 的 workspaces 模块内部写死了旧版 `dispatch workspace` IPC 调用，被 Hyprland 0.55+ 拒绝。上游 master 已修，随 0.16 发布解决。
怎么办：等升级，期间用 `Super+数字`。不要为此改配置，也不要换 waybar-git。

**在 tty 下跑 playbook，gsettings 任务报了警告**
现象：settings 角色的 gsettings 任务显示警告但不失败。
原因：tty/无图形会话下 D-Bus session 地址是猜的，设置可能写不进去。
怎么办：预期行为，忽略；下次在图形会话里重跑 `--tags settings` 即可。

**`try` 命令和 AUR 的 `try` 包**
现象：AUR 里搜到一个叫 `try` 的包，以为是这个项目装的。
原因：本项目的 `try` 是 `~/.local/bin/try`——tobi/try 仓库（Ruby）的 git clone 加 wrapper（见[应用说明 · try-cli](apps.md#try-cli)）。AUR 那个是同名的另一个工具。
怎么办：不要装 AUR 的 `try`；要更新本项目的 try 就到 `~/.local/share/try-cli` 里 `git pull`。

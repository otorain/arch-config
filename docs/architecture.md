# 架构与原理

> 概念讲解：这套配置为什么是这样组织的。不含操作步骤（操作见[维护与开发](maintenance.md)）。

## 总览：一个 playbook，四个角色

整个项目只有一个入口 `playbooks/site.yml`：对 `hosts: desktop` 依次跑 `base → software → settings → services` 四个角色。没有 CI、没有测试套件——验证手段就是 ansible 自带的语法检查和 dry run（见[维护与开发](maintenance.md)）。所有任务幂等，所以"再跑一遍"永远是安全的操作，这也是整个维护模型的基础：想改什么就改仓库，然后重跑，让 Ansible 把系统收敛到仓库描述的状态。

## 角色分层与顺序

- **base**（`roles/base/tasks/main.yml`）：与具体软件无关的系统底座——preflight 断言（必须是 Arch、非 root、有网络）、时区、locale（生成 en_US + zh_CN，`LANG=zh_CN.UTF-8` 但 `LC_MESSAGES=en_US.UTF-8`，界面中文而终端报错保持英文）、zram、sshd 加固、XDG 用户目录。
- **software**（`roles/software/`）：装全部包，并按 app 部署配置。绝大多数"这台机器上有什么"都发生在这里。
- **settings**（`roles/settings/`）：桌面外观层——GTK/Qt/Kvantum/字体配置、fcitx5 皮肤、gsettings、SDDM 主题。它在 software 之后，因为主题包（Colloid、catppuccin SDDM 主题）都是 software 装的；任务里找不到主题时只警告跳过。
- **services**（`roles/services/`）：把用户加进 `docker`/`vboxusers`/`libvirt` 组、设默认 shell 为 zsh、enable 系统与用户 systemd 单元。它**必须**在 software 之后：那些用户组和 `/usr/bin/zsh` 都是软件包装出来的，放到 base 里执行会因组/文件不存在而失败（该文件开头的注释明说了这一点）。

顺序即依赖图：base 不依赖任何东西；software 提供包；settings 消费包里的主题；services 消费包带来的组、shell 和单元文件。

## 软件清单与配置分离

software 角色里，"装什么"和"怎么配"是两类文件：所有官方仓库包集中在 `tasks/_pacman.yml`（按 `# ===` 分组注释归类），所有 AUR 包集中在 `tasks/_aur.yml`；而 31 个 `tasks/<app>.yml` 一律只管部署——拷贝配置、放用户服务、注册 zsh fragment。好处是双方向的：想知道"系统里装了什么"只看两个文件；想知道"某个软件配成什么样"只看它的 app 文件，不用在几百行包清单里翻。

`main.yml` 开头的三个基础设施 include 有硬顺序：`_pacman → yay → _aur`。yay 本身要从 AUR bootstrap（`tasks/yay.yml`：clone yay-bin、makepkg、`pacman -U`），依赖 `_pacman.yml` 里的 `base-devel` 和 `git`；`_aur.yml` 则要求 yay 二进制已就位。`_aur_one.yml` 是单包 helper：先查已装、再探可用、装失败打印 stderr 末尾并继续——AUR 包名随时间漂移，一个包失败不该拖垮整个运行。

## aur_builder：无 tty 的 AUR 安装

AUR 安装有一个 root 权限悖论：makepkg 拒绝以 root 构建（安全设计），但 yay 构建完的最后一步是内部调 `sudo pacman -U` 安装——playbook 在无 tty 环境（脚本、agent、CI）里运行时，sudo 无法弹出来问密码。解法是专用构建用户 `aur_builder`：系统用户（uid < 1000，SDDM 登录界面不可见）、nologin shell、密码锁定，`/etc/sudoers.d/10-aur_builder` 只授予它对 `/usr/bin/pacman` 一条命令的 NOPASSWD（kewlfft.aur 模式）。安装任务用 `become_user: aur_builder` 执行，并显式设 `HOME=/home/aur_builder`——Ansible 的 sudo become 不带 `-H`，不设的话 yay 会把缓存写进登录用户的 `~/.cache` 然后权限拒绝。登录用户自己的 sudo 不受影响，仍然全程要密码。

## 模板渲染流：host_vars → jinja2 → ~/.config

四个文件不是静态拷贝而是 jinja2 模板：`hyprland.lua.j2`、`waybar/config.jsonc.j2`、`wechat/wechat.desktop.j2`、`gmail/gmail.desktop.j2`（gmail 是因为 `Exec` 里要展开 home 路径）。模板消费的机器变量集中在 `inventory/host_vars/desktop.yml`：`monitor`、`scale`、`net_interface`。这条单向流意味着：机器差异永远改 host_vars，通用逻辑改模板，而 `~/.config/` 下的渲染产物永远不该手改——下次运行会被覆盖。同理，`luac -p` 语法检查只对渲染产物有意义，模板里混着 jinja 语法，直接校验会误报。

## zsh：skeleton + conf.d

zsh 配置采用"骨架 + 碎片"模式，核心是所有权分离。`~/.zshrc` 以 `force: false` 部署——新机器上放一次骨架，之后文件归用户，playbook 永不覆盖；骨架唯一不可替代的职责是按字典序 source `~/.config/zsh/conf.d/*.zsh`。真正由 playbook 管理的是 conf.d 里的 15 个编号 fragment（`files/zsh/[0-9]*.zsh`，fileglob 统一部署）：05 oh-my-zsh、10 别名、20 zoxide、30 fzf……99 语法高亮。编号控制加载顺序，语法高亮必须在最后（它要高亮此前定义的所有东西）。为了防止"用户重写 `.zshrc` 时弄丢 source 循环、所有 shell 集成静默失效"，playbook 每次运行都会 grep 检查，缺失则警告——这是整个项目里少见的"管理用户所有文件"的折衷：不强制，但提醒。

## git 配置的所有权模型

同样的所有权思路用在 git 上，但分工相反：`~/.config/git/config` 归用户——首次运行 git app 时交互式问 `user.name`/`user.email` 后创建，之后永不覆盖；它通过 `[include] path = ~/.config/git/custom` 引入 playbook 管理的 `custom`（delta pager、catppuccin 主题，后者再 include 同目录的 `catppuccin.gitconfig`）。个人身份和共享美化各归各位：playbook 重跑能更新主题，却永远碰不到你的 name/email；如果 include 行被弄丢，grep+warn 组合会提醒（与 zsh 同一手法）。

## 主题体系：catppuccin-mocha 贯穿一切

视觉统一靠"一个主题、n 个落点"：catppuccin-mocha（蓝 accent）分别落在 GTK（Colloid-Dark-Catppuccin，AUR；GTK4 用符号链接把主题的 gtk-4.0 目录接进 `~/.config/gtk-4.0`）、Qt（Kvantum + `QT_STYLE_OVERRIDE=kvantum`，`QT_QPA_PLATFORMTHEME=gtk3`）、fcitx5 皮肤（clone catppuccin/fcitx5）、delta（`~/.config/git/catppuccin.gitconfig`）、zsh 语法高亮、atuin、mpv、zathura、kitty、rofi、dunst、hyprland 边框颜色，直到 SDDM 登录界面（含同一张壁纸 `assets/colin-watts.jpg`）。所以新增任何配置时默认跟着 catppuccin-mocha 蓝色系走，整个桌面就不会出现视觉孤岛。

## 弹层机制：gtk4-layer-shell

waybar 的天气和日历弹层（见[应用说明 · waybar](apps.md#waybar)）不是普通窗口，而是 gtk4-layer-shell 的全屏透明 layer surface——这就是 hyprland 模板里特意注释"window_rule 对它不适用"的原因，位置、圆角、"点击外部关闭"全部在脚本内部实现。两个关键机制：

- **LD_PRELOAD re-exec**：gtk4-layer-shell 必须先于 libwayland-client 加载，而 PyGObject 的 dlopen 顺序保证不了这一点（晚加载会静默退化成普通平铺窗口，报 "Failed to initialize layer surface"）。所以脚本开头检测到自己没带 `LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so` 就用 `os.execv` 重启自己一次。这段不能删。
- **AT-SPI 锚定**：waybar 自己不暴露模块位置，`waybar_geom.py` 通过 GTK3 atk-bridge 发布在 AT-SPI 总线上的控件树，按文本特征（天气找 "°C"，时钟找当天日期）拿到模块标签的屏幕坐标，弹层才能精确锚定在模块正下方；失败则退回屏幕居中。

另外，弹层要盖过 Colloid 主题的样式时，CSS 必须以 `Gtk.STYLE_PROVIDER_PRIORITY_USER` 优先级注册，因为主题本身就加载在 USER 优先级（800）上。设计上明确不要 focus-out 自动关闭——关闭路径只有 Esc、点击卡片外、再点一次模块这三条。

## 命名冲突：try

`~/.local/bin/try` 是 tobi/try（Ruby 写的目录实验工具）的 git clone 加一层 wrapper（见[应用说明 · try-cli](apps.md#try-cli)），而 AUR 里有个同名 `try` 包是完全不同的另一个工具。playbook 刻意用 clone 安装（`tasks/try-cli.yml`）而不是 AUR 包——装上 AUR 的 `try` 会顶掉 PATH 里的 wrapper，shell 集成（`60-try.zsh` 的 `try init ~/src/tries`）随即失效。

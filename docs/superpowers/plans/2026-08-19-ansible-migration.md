# Ansible Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `install.sh` + `scripts/` + `packages/` + `dotfiles/` with a modular Ansible project under `playbooks/` (4 layer roles, per-app task files).

**Architecture:** Single playbook `site.yml` runs roles `base → software → settings → services` against inventory host `desktop` (localhost, connection=local). The `software` role centralizes package installs in `_pacman.yml`/`yay.yml`/`_aur.yml` (hard order constraint) and deploys per-app config from `apps/<app>.yml` task files, each tagged with the app name for partial runs.

**Tech Stack:** ansible-core + community.general (Arch `ansible` package), Jinja2 templates, no external collections.

**Spec:** `docs/superpowers/specs/2026-08-19-ansible-migration-design.md`

## Global Constraints

- All playbook comments and output strings in English; user-facing UI text inside dotfiles (desktop entry Name/Comment, waybar labels) stays Chinese.
- Everything themes catppuccin-mocha, blue accent.
- Do NOT run stylua on hyprland.lua or its template (4-space indent, aligned `=`).
- Do NOT git-commit anything (project convention: no git history; the user manages VCS).
- hyprland config stays **Lua** (`hyprland.lua`), never generate `hyprland.conf`.
- weather.py / calendar.py keep their `LD_PRELOAD` gtk4-layer-shell re-exec block and `PRIORITY_USER` CSS; deploy them verbatim, add no Hyprland window_rule.
- `~/.config/git/config` is created once, never overwritten.
- `~/.local/bin/try` wraps the tobi/try git clone — never the AUR `try` package.
- All `ansible-playbook` commands run from `playbooks/` (ansible.cfg lives there).
- Privilege model: play runs as the user; root tasks use `become: true`; entry point is `ansible-playbook site.yml --ask-become-pass`.
- **Execution note for agents:** steps requiring `become` need the user's sudo password — hand those commands to the user to run; agents run syntax checks and non-privileged steps themselves.
- `--check --diff` is informational only: `command`-based tasks (yay, gsettings, npm) are skipped or inaccurate in check mode. Real verification = running the tag.
- `community.general.pacman` with `update_cache: true` always reports changed; that noise is expected.

## File Structure

```
playbooks/
├── ansible.cfg                  # Task 1
├── site.yml                     # Task 1
├── inventory/
│   ├── hosts.ini                # Task 1
│   ├── group_vars/all.yml       # Task 1 (extended in Tasks 15)
│   └── host_vars/desktop.yml    # Task 1
└── roles/
    ├── base/                    # Task 2 (tasks + handlers)
    ├── software/                # Tasks 3-13
    │   ├── tasks/main.yml       # Task 3 (include order, tags)
    │   ├── tasks/apps/_pacman.yml   # Task 3
    │   ├── tasks/apps/yay.yml       # Task 3
    │   ├── tasks/apps/_aur.yml      # Task 3 (+ _aur_one.yml)
    │   ├── tasks/apps/zsh.yml       # Task 4
    │   ├── tasks/apps/cli-tools.yml # Task 5
    │   ├── tasks/apps/kitty.yml     # Task 6
    │   ├── tasks/apps/nvim.yml      # Task 6
    │   ├── tasks/apps/git.yml       # Task 7
    │   ├── tasks/apps/mpv.yml       # Task 8
    │   ├── tasks/apps/fcitx5.yml    # Task 9
    │   ├── tasks/apps/hyprland.yml  # Task 10
    │   ├── tasks/apps/waybar.yml    # Task 11
    │   ├── tasks/apps/web-apps.yml  # Task 12
    │   ├── tasks/apps/gui-apps.yml  # Task 12
    │   ├── tasks/apps/dev.yml       # Task 13
    │   ├── files/apps/<app>/…       # Tasks 4-13 (mirror $HOME layout)
    │   ├── templates/apps/…         # Tasks 10-12
    │   └── handlers/main.yml        # Task 3
    ├── settings/                # Task 14 (tasks + files + handlers)
    └── services/                # Task 15
```

File-move convention: `dotfiles/` content moves to
`playbooks/roles/software/files/apps/<app>/` **preserving the $HOME-relative
path**, so `dotfiles/.config/kitty/kitty.conf` becomes
`files/apps/kitty/.config/kitty/kitty.conf`. Each app then deploys with one
`copy: src=apps/<app>/ dest={{ home }}/` task. Use plain `mv` (no git
commands).

---

### Task 1: Scaffold playbooks/

**Files:**
- Create: `playbooks/ansible.cfg`
- Create: `playbooks/site.yml`
- Create: `playbooks/inventory/hosts.ini`
- Create: `playbooks/inventory/group_vars/all.yml`
- Create: `playbooks/inventory/host_vars/desktop.yml`

**Interfaces:**
- Produces: vars `home`, `uid`, `timezone`, `gtk_theme`, `icon_theme`, `gtk_font`, `npm_globals` (group_vars); `monitor`, `scale`, `net_interface` (host_vars). Every later task consumes these names exactly.

- [ ] **Step 1: Create directory skeleton**

```bash
mkdir -p playbooks/inventory/group_vars playbooks/inventory/host_vars \
  playbooks/roles/{base,software,settings,services}/tasks \
  playbooks/roles/{base,software,settings}/handlers \
  playbooks/roles/software/tasks/apps \
  playbooks/roles/software/files/apps \
  playbooks/roles/software/templates/apps \
  playbooks/roles/settings/files
```

- [ ] **Step 2: `playbooks/ansible.cfg`**

```ini
[defaults]
inventory = inventory/hosts.ini
interpreter_python = auto_silent
retry_files_enabled = false
display_skipped_hosts = false
diff = true
```

- [ ] **Step 3: `playbooks/inventory/hosts.ini`**

The host is literally named `desktop` (alias for localhost); `host_vars/desktop.yml` binds to that name.

```ini
desktop ansible_connection=local
```

- [ ] **Step 4: `playbooks/inventory/group_vars/all.yml`**

```yaml
---
home: "{{ ansible_env.HOME }}"
uid: "{{ ansible_user_uid }}"
timezone: Asia/Shanghai
gtk_theme: Colloid-Dark-Catppuccin
icon_theme: Papirus-Dark
gtk_font: Noto Sans 12
npm_globals:
  - "@openai/codex"
  - "@mariozechner/pi-coding-agent"
  - "@deepseek-ai/dsh"
```

- [ ] **Step 5: `playbooks/inventory/host_vars/desktop.yml`**

```yaml
---
monitor: DP-1
scale: "1.25"
net_interface: wlp6s0
```

(`scale` is quoted: it lands in both a Lua number context and a shell env assignment; Jinja renders `1.25` either way, quoting keeps YAML from storing a float that could render as `1.250` nowhere — belt and braces, keep the quotes.)

- [ ] **Step 6: `playbooks/site.yml`**

```yaml
---
- name: Arch Linux desktop setup
  hosts: desktop
  gather_facts: true
  roles:
    - { role: base, tags: base }
    - { role: software, tags: software }
    - { role: settings, tags: settings }
    - { role: services, tags: services }
```

- [ ] **Step 7: Create empty role entrypoints so the playbook parses**

Each of `roles/{base,software,settings,services}/tasks/main.yml`:

```yaml
---
```

- [ ] **Step 8: Verify**

```bash
cd playbooks
ansible desktop -m ping
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --list-tasks
```

Expected: ping `SUCCESS`; syntax check passes; list-tasks shows the 4 roles.

---

### Task 2: `base` role — basic system setup

**Files:**
- Create: `playbooks/roles/base/tasks/main.yml`
- Create: `playbooks/roles/base/handlers/main.yml`

**Interfaces:**
- Consumes: `timezone`, `uid` (all.yml).
- Produces: locale `zh_CN.UTF-8`/`en_US.UTF-8` generated; user in groups wheel/docker/vboxusers/libvirt; shell zsh. Nothing later references these as vars.

- [ ] **Step 1: `roles/base/handlers/main.yml`**

```yaml
---
- name: Regenerate locales
  become: true
  ansible.builtin.command: locale-gen
```

- [ ] **Step 2: `roles/base/tasks/main.yml`**

```yaml
---
# Preflight
- name: Assert running on Arch Linux
  ansible.builtin.stat:
    path: /etc/arch-release
  register: arch_release

- name: Assert Arch Linux and non-root
  ansible.builtin.assert:
    that:
      - arch_release.stat.exists
      - ansible_user_id != "root"
    fail_msg: "this playbook only supports Arch Linux, run as a normal user"

- name: Check network connectivity
  ansible.builtin.uri:
    url: https://archlinux.org
    method: HEAD
    timeout: 5
    status_code: [200, 301]

# Timezone
- name: Get current timezone
  ansible.builtin.command: timedatectl show -p Timezone --value
  register: current_tz
  changed_when: false

- name: Set timezone
  become: true
  ansible.builtin.command: "timedatectl set-timezone {{ timezone }}"
  when: current_tz.stdout != timezone

# Locale: en_US + zh_CN generated; Chinese UI, English terminal messages
- name: Enable locales in /etc/locale.gen
  become: true
  ansible.builtin.lineinfile:
    path: /etc/locale.gen
    regexp: "^#?({{ item }} UTF-8)"
    line: '\1'
    backrefs: true
  loop:
    - en_US.UTF-8
    - zh_CN.UTF-8
  notify: Regenerate locales

- name: Write /etc/locale.conf
  become: true
  ansible.builtin.copy:
    dest: /etc/locale.conf
    content: |
      LANG=zh_CN.UTF-8
      LC_MESSAGES=en_US.UTF-8
    mode: "0644"

# zram
- name: Write zram-generator config
  become: true
  ansible.builtin.copy:
    dest: /etc/systemd/zram-generator.conf
    content: |
      [zram0]
      zram-size = ram / 2
      compression-algorithm = zstd
    mode: "0644"

# SSH hardening
- name: Disable SSH root login
  become: true
  ansible.builtin.copy:
    dest: /etc/ssh/sshd_config.d/99-hardening.conf
    content: |
      PermitRootLogin no
    mode: "0644"

# User
- name: Add user to groups
  become: true
  ansible.builtin.user:
    name: "{{ ansible_user_id }}"
    groups: wheel,docker,vboxusers,libvirt
    append: true

- name: Set default shell to zsh
  become: true
  ansible.builtin.user:
    name: "{{ ansible_user_id }}"
    shell: /usr/bin/zsh
```

- [ ] **Step 3: Verify**

```bash
cd playbooks
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --tags base --check --diff   # informational
```

Then hand to the user (needs sudo):

```bash
ansible-playbook site.yml --tags base --ask-become-pass
```

Expected: `ok`/`changed` on all, no failures; re-run reports all `ok`.

---

### Task 3: `software` role infrastructure — _pacman / yay / _aur / main / handlers

**Files:**
- Create: `playbooks/roles/software/tasks/apps/_pacman.yml`
- Create: `playbooks/roles/software/tasks/apps/yay.yml`
- Create: `playbooks/roles/software/tasks/apps/_aur.yml`
- Create: `playbooks/roles/software/tasks/apps/_aur_one.yml`
- Create: `playbooks/roles/software/tasks/main.yml`
- Create: `playbooks/roles/software/handlers/main.yml`

**Interfaces:**
- Produces: all official + AUR packages installed; handlers `Reload waybar`, `Update desktop database`, `Update icon cache`, `Refresh font cache` (exact names — later tasks notify them).
- Produces: tags `packages`, `yay`, `aur`.

- [ ] **Step 1: `tasks/apps/_pacman.yml`** — full list transcribed from `packages/pacman.txt`, comment groups preserved, plus `ansible-lint` at the end of CLI tools (new, for plan verification):

```yaml
---
# All official-repo packages in one shot (replaces packages/pacman.txt).
# Grouped by owning application; a package with no app lives in its group.
- name: Install official-repo packages
  become: true
  community.general.pacman:
    update_cache: true
    state: present
    name:
      # === Base tools ===
      - base-devel
      - git
      - wget
      - curl
      - zsh
      - zsh-syntax-highlighting
      - vim
      - ntfs-3g
      - unzip
      - bzip2
      - pbzip2
      - man-db
      - man-pages
      - btrfs-progs
      # === System services ===
      - networkmanager
      - network-manager-applet
      - zram-generator
      - bluez
      - bluez-utils
      - blueman
      - openssh
      - fail2ban
      - cups
      - avahi
      - nss-mdns
      - udisks2
      - gvfs
      - earlyoom
      - polkit
      - xdg-user-dirs
      - xdg-utils
      - libnotify
      - playerctl
      - brightnessctl
      # === Virtualization / Containers ===
      - docker
      - docker-compose
      - libvirt
      - qemu-desktop
      - virt-manager
      - dnsmasq
      - virtualbox
      - virtualbox-host-dkms
      # === Audio (full PipeWire suite) ===
      - pipewire
      - pipewire-alsa
      - pipewire-pulse
      - pipewire-jack
      - wireplumber
      - pavucontrol
      # === Fonts ===
      - noto-fonts
      - noto-fonts-cjk
      - noto-fonts-emoji
      - ttf-cascadia-code-nerd
      - otf-font-awesome
      # === Hyprland desktop stack ===
      - hyprland
      - hyprpaper
      - hypridle
      - hyprlock
      - hyprpicker
      - hyprpolkitagent
      - gtk-layer-shell
      - gtk4-layer-shell
      - xdg-desktop-portal-hyprland
      - xdg-desktop-portal-gtk
      - waybar
      - rofi
      - dunst
      - grim
      - slurp
      - satty
      - wl-clipboard
      - cliphist
      - qt5-wayland
      - qt6-wayland
      - kvantum
      - qt5ct
      - qt6ct
      - nwg-look
      - sddm
      - python-gobject
      # === Input method (fcitx5 + rime) ===
      - fcitx5
      - fcitx5-gtk
      - fcitx5-qt
      - fcitx5-configtool
      - fcitx5-rime
      # === Programming languages ===
      - rustup
      - python
      - python-pip
      - ruby
      - ruby-bundler
      - nodejs
      - npm
      - bun
      - pnpm
      - go
      - mise
      # === CLI tools ===
      - bat
      - btop
      - duf
      - tmux
      - eza
      - fastfetch
      - ripgrep
      - fd
      - fzf
      - zoxide
      - direnv
      - jq
      - atuin
      - lazygit
      - git-delta
      - tree-sitter-cli
      - duckdb
      - yazi
      - uv
      - shellcheck
      - shfmt
      - stylua
      - python-isort
      - gofumpt
      - eslint_d
      - ansible
      - ansible-lint
      - neovim
      # === LSP / Development ===
      - lua-language-server
      - pyright
      - ruff
      - clang
      - gopls
      - typescript-language-server
      - yaml-language-server
      - bash-language-server
      - dockerfile-language-server
      # === GUI apps ===
      - kitty
      - zathura
      - zathura-pdf-mupdf
      - mpv
      - mpv-mpris
      - obsidian
      - firefox
      - pcmanfm
      - nfs-utils
      - swayimg
      - papirus-icon-theme
      - zed
```

- [ ] **Step 2: `tasks/apps/yay.yml`** (absorbs `scripts/install-yay.sh`; whole block skipped when yay exists — always the case on the current machine):

```yaml
---
# Bootstrap yay from AUR (yay-bin). Needs base-devel + git from _pacman.yml.
- name: Check if yay is installed
  ansible.builtin.command: yay --version
  register: yay_check
  changed_when: false
  failed_when: false

- name: Bootstrap yay
  when: yay_check.rc != 0
  block:
    - name: Create build directory
      ansible.builtin.tempfile:
        state: directory
        suffix: .yay
      register: yay_tmp

    - name: Clone yay-bin
      ansible.builtin.git:
        repo: https://aur.archlinux.org/yay-bin.git
        dest: "{{ yay_tmp.path }}/yay-bin"
        depth: 1

    - name: Build yay-bin (deps already satisfied, no sudo inside)
      ansible.builtin.command: makepkg -s --noconfirm
      args:
        chdir: "{{ yay_tmp.path }}/yay-bin"

    - name: Find built package
      ansible.builtin.find:
        paths: "{{ yay_tmp.path }}/yay-bin"
        patterns: "yay-bin-*.pkg.tar.zst"
      register: yay_pkg

    - name: Install yay-bin
      become: true
      ansible.builtin.command: "pacman -U --noconfirm {{ yay_pkg.files[0].path }}"

    - name: Clean up build directory
      ansible.builtin.file:
        path: "{{ yay_tmp.path }}"
        state: absent
```

- [ ] **Step 3: `tasks/apps/_aur.yml` + `_aur_one.yml`** (same warn-and-continue semantics as the old `aur_pkgs` stage; full list from `packages/aur.txt`):

```yaml
---
# All AUR packages (replaces packages/aur.txt). Requires yay (apps/yay.yml).
# Per-package probe + warn-and-continue so one bad package never fails the run.
- name: Install AUR packages
  ansible.builtin.include_tasks: apps/_aur_one.yml
  loop:
    # === Browsers ===
    - google-chrome
    # === JetBrains IDE ===
    - pycharm
    - rubymine
    # === Messaging ===
    - wechat-bin
    # === Office / Dictionaries ===
    - wps-office-cn
    - goldendict-ng
    # === mpv scripts ===
    - mpv-uosc
    - mpv-thumbfast-git
    - mpv-sponsorblock
    # === AI coding tools ===
    - opencode-bin
    - herdr-bin
    - kimi-code
    # === IME dictionaries ===
    - rime-ice-git
    # === Dev tools ===
    - terraform-ls
    - vscode-langservers-extracted
    - prettierd
    - vagrant
    # === Themes ===
    - colloid-catppuccin-gtk-theme-git
    - catppuccin-cursors-mocha
    - catppuccin-sddm-theme-mocha
    - rofi-power-menu
    # === Misc ===
    - dropbox
    - virtualbox-ext-oracle
  loop_control:
    loop_var: pkg
```

`_aur_one.yml`:

```yaml
---
- name: "AUR: check installed: {{ pkg }}"
  ansible.builtin.command: "yay -Qi {{ pkg }}"
  register: aur_qi
  changed_when: false
  failed_when: false

- name: "AUR: install if missing: {{ pkg }}"
  when: aur_qi.rc != 0
  block:
    - name: "AUR: probe availability: {{ pkg }}"
      ansible.builtin.command: "yay -Si {{ pkg }}"
      register: aur_si
      changed_when: false
      failed_when: false

    - name: "AUR: warn if not resolvable: {{ pkg }}"
      ansible.builtin.debug:
        msg: "not in AUR (skipped): {{ pkg }}"
      when: aur_si.rc != 0

    - name: "AUR: install: {{ pkg }}"
      ansible.builtin.command: "yay -S --needed --noconfirm {{ pkg }}"
      when: aur_si.rc == 0
      register: aur_install
      failed_when: false

    - name: "AUR: warn on failure: {{ pkg }}"
      ansible.builtin.debug:
        msg: "install failed, handle manually: {{ pkg }}"
      when: aur_si.rc == 0 and aur_install is failed
```

- [ ] **Step 4: `roles/software/handlers/main.yml`**

```yaml
---
- name: Reload waybar
  ansible.builtin.command: pkill -SIGUSR2 -x waybar
  failed_when: false
  listen: Reload waybar

- name: Update desktop database
  ansible.builtin.command: "update-desktop-database {{ home }}/.local/share/applications"
  failed_when: false
  listen: Update desktop database

- name: Update icon cache
  ansible.builtin.command: "gtk-update-icon-cache -f {{ home }}/.local/share/icons/hicolor"
  failed_when: false
  listen: Update icon cache

- name: Refresh font cache
  ansible.builtin.command: fc-cache -f
  failed_when: false
  listen: Refresh font cache
```

(`listen` + `name` kept identical so either form works when notified.)

- [ ] **Step 5: `roles/software/tasks/main.yml`** — hard order: `_pacman → yay → _aur`, then apps alphabetically. Comment must state the constraint:

```yaml
---
# Order-sensitive infrastructure first: _pacman → yay → _aur.
# yay needs base-devel + git from _pacman; _aur needs the yay binary.
# App files below may be ordered freely; each deploys config only
# (packages live in _pacman.yml / _aur.yml).
- name: Packages (official repos)
  ansible.builtin.include_tasks: apps/_pacman.yml
  tags: packages

- name: yay bootstrap
  ansible.builtin.include_tasks: apps/yay.yml
  tags: [yay, aur]

- name: Packages (AUR)
  ansible.builtin.include_tasks: apps/_aur.yml
  tags: aur

- name: App: cli-tools
  ansible.builtin.include_tasks: apps/cli-tools.yml
  tags: cli-tools

- name: App: dev
  ansible.builtin.include_tasks: apps/dev.yml
  tags: dev

- name: App: fcitx5
  ansible.builtin.include_tasks: apps/fcitx5.yml
  tags: fcitx5

- name: App: git
  ansible.builtin.include_tasks: apps/git.yml
  tags: git

- name: App: gui-apps
  ansible.builtin.include_tasks: apps/gui-apps.yml
  tags: gui-apps

- name: App: hyprland
  ansible.builtin.include_tasks: apps/hyprland.yml
  tags: hyprland

- name: App: kitty
  ansible.builtin.include_tasks: apps/kitty.yml
  tags: kitty

- name: App: mpv
  ansible.builtin.include_tasks: apps/mpv.yml
  tags: mpv

- name: App: nvim
  ansible.builtin.include_tasks: apps/nvim.yml
  tags: nvim

- name: App: waybar
  ansible.builtin.include_tasks: apps/waybar.yml
  tags: waybar

- name: App: web-apps
  ansible.builtin.include_tasks: apps/web-apps.yml
  tags: web-apps

- name: App: zsh
  ansible.builtin.include_tasks: apps/zsh.yml
  tags: zsh
```

- [ ] **Step 6: Create placeholder app files so main.yml parses**

For each name in `cli-tools dev fcitx5 git gui-apps hyprland kitty mpv nvim waybar web-apps zsh`, create `tasks/apps/<name>.yml` containing just:

```yaml
---
```

- [ ] **Step 7: Verify**

```bash
cd playbooks
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --list-tasks --tags software
ansible-lint site.yml || true   # style warnings acceptable at this stage
```

Expected: parses; 12 includes listed under the software role. Do NOT run `--tags packages,aur` yet (30+ min pacman/AUR run on an already-provisioned machine is safe but slow; the user may run it once at cutover in Task 16 — everything in the lists is already installed, so it will be mostly no-ops).

---

### Task 4: `zsh` app — skeleton .zshrc + conf.d fragments + oh-my-zsh

**Files:**
- Create: `playbooks/roles/software/files/apps/zsh/.zshrc`
- Create: `playbooks/roles/software/files/apps/zsh/.config/zsh/conf.d/90-catppuccin-highlight.zsh`
- Create: `playbooks/roles/software/files/apps/zsh/.config/zsh/conf.d/99-syntax-highlighting.zsh`
- Move: `dotfiles/.local/share/catppuccin_mocha-zsh-syntax-highlighting.zsh` → `playbooks/roles/software/files/apps/zsh/.local/share/catppuccin_mocha-zsh-syntax-highlighting.zsh`
- Modify: `playbooks/roles/software/tasks/apps/zsh.yml`

**Interfaces:**
- Produces: `~/.config/zsh/conf.d/` directory convention; fragments `20/30/50/70/80` (cli-tools, Task 5), `40` (kitty, Task 6), `15/60` (dev, Task 13) drop into it. Fragment interface: any `*.zsh` file, sourced in lexical order, `99-*` must stay last.

- [ ] **Step 1: Skeleton `files/apps/zsh/.zshrc`** (tool integrations removed — they now live in fragments):

```zsh
# .zshrc — skeleton. Tool integrations live in ~/.config/zsh/conf.d/*.zsh,
# deployed per-app by the ansible software role (playbooks/roles/software).

# === Environment variables ===
export EDITOR=nvim
export DIRENV_LOG_FORMAT="direnv: %s"

# pnpm global package dir + ~/.local/bin (uv tool install, etc.)
export PATH="$HOME/.local/share/pnpm:$HOME/.local/bin:$PATH"

# === oh-my-zsh ===
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=robbyrussell
plugins=(git sudo history)
source "$ZSH/oh-my-zsh.sh"

# === History ===
HISTSIZE="10000"
SAVEHIST="10000"
HISTFILE="$HOME/.zsh_history"
setopt HIST_FCNTL_LOCK HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY
setopt NO_APPEND_HISTORY NO_EXTENDED_HISTORY NO_HIST_EXPIRE_DUPS_FIRST
setopt NO_HIST_FIND_NO_DUPS NO_HIST_IGNORE_ALL_DUPS NO_HIST_SAVE_NO_DUPS

# === Aliases ===
alias open=xdg-open

# === App-provided fragments (numbered, sourced in order) ===
for f in ~/.config/zsh/conf.d/*.zsh(N); do
  source "$f"
done
```

- [ ] **Step 2: `90-catppuccin-highlight.zsh`**

```zsh
# catppuccin mocha palette for zsh-syntax-highlighting (owned by: zsh app)
[[ -f ~/.local/share/catppuccin_mocha-zsh-syntax-highlighting.zsh ]] && \
  source ~/.local/share/catppuccin_mocha-zsh-syntax-highlighting.zsh
```

- [ ] **Step 3: `99-syntax-highlighting.zsh`**

```zsh
# syntax highlighting must be sourced last (owned by: zsh app)
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)
```

- [ ] **Step 4: Move the catppuccin highlight file**

```bash
mkdir -p playbooks/roles/software/files/apps/zsh/.local/share
mv dotfiles/.local/share/catppuccin_mocha-zsh-syntax-highlighting.zsh \
   playbooks/roles/software/files/apps/zsh/.local/share/
```

- [ ] **Step 5: `tasks/apps/zsh.yml`** (absorbs `scripts/install-oh-my-zsh.sh`):

```yaml
---
- name: Install oh-my-zsh
  ansible.builtin.git:
    repo: https://github.com/ohmyzsh/ohmyzsh.git
    dest: "{{ home }}/.oh-my-zsh"
    depth: 1
    update: false

- name: Deploy zsh files (.zshrc, conf.d fragments, highlight theme)
  ansible.builtin.copy:
    src: apps/zsh/
    dest: "{{ home }}/"
```

- [ ] **Step 6: Verify**

```bash
cd playbooks
ansible-playbook site.yml --syntax-check
zsh -n roles/software/files/apps/zsh/.zshrc
zsh -n roles/software/files/apps/zsh/.config/zsh/conf.d/90-catppuccin-highlight.zsh
zsh -n roles/software/files/apps/zsh/.config/zsh/conf.d/99-syntax-highlighting.zsh
ansible-playbook site.yml --tags zsh
```

Expected: all `zsh -n` pass; tag run reports changed for .zshrc + 2 fragments (first deploy); re-run reports all `ok`. Open a new shell and confirm prompt works.

---

### Task 5: `cli-tools` app — small-CLI zsh fragments + atuin/direnv config

**Files:**
- Create: `files/apps/cli-tools/.config/zsh/conf.d/{10-aliases,20-zoxide,30-fzf,50-yazi,70-direnv,80-atuin}.zsh`
- Move: `dotfiles/.config/atuin/` → `files/apps/cli-tools/.config/atuin/`
- Move: `dotfiles/.config/direnv/` → `files/apps/cli-tools/.config/direnv/`
- Modify: `playbooks/roles/software/tasks/apps/cli-tools.yml`

**Interfaces:**
- Consumes: `~/.config/zsh/conf.d/` convention from Task 4.

- [ ] **Step 1: Move configs**

```bash
mkdir -p playbooks/roles/software/files/apps/cli-tools/.config
mv dotfiles/.config/atuin playbooks/roles/software/files/apps/cli-tools/.config/
mv dotfiles/.config/direnv playbooks/roles/software/files/apps/cli-tools/.config/
```

- [ ] **Step 2: Write fragments**

`10-aliases.zsh`:
```zsh
# aliases for cli tools (owned by: cli-tools app)
alias lg=lazygit
```

`20-zoxide.zsh`:
```zsh
# zoxide: smarter cd (owned by: cli-tools app)
eval "$(zoxide init zsh)"
```

`30-fzf.zsh`:
```zsh
# fzf keybindings/completion, interactive shells only (owned by: cli-tools app)
if [[ $options[zle] = on ]]; then
  source <(fzf --zsh)
fi
```

`50-yazi.zsh`:
```zsh
# yazi: cd into the directory on exit (owned by: cli-tools app)
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  if cwd="$(<"$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
```

`70-direnv.zsh`:
```zsh
# direnv hook (owned by: cli-tools app)
eval "$(direnv hook zsh)"
```

`80-atuin.zsh`:
```zsh
# atuin: only take over Ctrl+R, keep default up-arrow behavior (owned by: cli-tools app)
if [[ $options[zle] = on ]]; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi
```

- [ ] **Step 3: `tasks/apps/cli-tools.yml`**

```yaml
---
- name: Deploy cli-tools files (atuin/direnv config, zsh fragments)
  ansible.builtin.copy:
    src: apps/cli-tools/
    dest: "{{ home }}/"
```

- [ ] **Step 4: Verify**

```bash
cd playbooks
ansible-playbook site.yml --tags cli-tools
for f in roles/software/files/apps/cli-tools/.config/zsh/conf.d/*.zsh; do zsh -n "$f" || exit 1; done
zsh -ic 'type y lg' </dev/null
```

Expected: tag run changed on first deploy, `ok` on re-run; `zsh -n` all pass; `y` is a function, `lg` an alias.

---

### Task 6: `kitty` + `nvim` apps

**Files:**
- Move: `dotfiles/.config/kitty/` → `files/apps/kitty/.config/kitty/`
- Create: `files/apps/kitty/.config/zsh/conf.d/40-kitty.zsh`
- Move: `dotfiles/.config/nvim/` → `files/apps/nvim/.config/nvim/`
- Modify: `tasks/apps/kitty.yml`, `tasks/apps/nvim.yml`

- [ ] **Step 1: Move files**

```bash
mkdir -p playbooks/roles/software/files/apps/kitty/.config \
         playbooks/roles/software/files/apps/nvim/.config
mv dotfiles/.config/kitty playbooks/roles/software/files/apps/kitty/.config/
mv dotfiles/.config/nvim playbooks/roles/software/files/apps/nvim/.config/
```

- [ ] **Step 2: `40-kitty.zsh`** (verbatim from the old .zshrc):

```zsh
# kitty shell integration (owned by: kitty app)
if test -n "$KITTY_INSTALLATION_DIR"; then
  export KITTY_SHELL_INTEGRATION="no-rc"
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
fi
```

- [ ] **Step 3: Task files**

`tasks/apps/kitty.yml`:
```yaml
---
- name: Deploy kitty files (config, zsh integration fragment)
  ansible.builtin.copy:
    src: apps/kitty/
    dest: "{{ home }}/"
```

`tasks/apps/nvim.yml`:
```yaml
---
- name: Deploy nvim config (LazyVim starter; plugins pulled by lazy.nvim on first launch)
  ansible.builtin.copy:
    src: apps/nvim/
    dest: "{{ home }}/"
```

- [ ] **Step 4: Verify**

```bash
cd playbooks
ansible-playbook site.yml --tags kitty,nvim
zsh -n roles/software/files/apps/kitty/.config/zsh/conf.d/40-kitty.zsh
ls ~/.config/nvim/init.lua ~/.config/kitty/kitty.conf
```

---

### Task 7: `git` app — delta/catppuccin config + one-time identity

**Files:**
- Move: `dotfiles/.config/git/{custom,catppuccin.gitconfig}` → `files/apps/git/.config/git/`
- Modify: `tasks/apps/git.yml`

**Interfaces:**
- Consumes: `home`.

- [ ] **Step 1: Move files**

```bash
mkdir -p playbooks/roles/software/files/apps/git/.config
mv dotfiles/.config/git playbooks/roles/software/files/apps/git/.config/
```

- [ ] **Step 2: `tasks/apps/git.yml`** — identity via conditional `pause` (prompts only when the file is missing; this replaces the spec's `vars_prompt`, which would prompt on every run):

```yaml
---
- name: Deploy git shared config (delta + catppuccin, included by ~/.config/git/config)
  ansible.builtin.copy:
    src: apps/git/
    dest: "{{ home }}/"

- name: Check for existing git identity file
  ansible.builtin.stat:
    path: "{{ home }}/.config/git/config"
  register: gitconfig

- name: Verify existing git config includes the dotfiles-managed file
  when: gitconfig.stat.exists
  block:
    - name: Check include of ~/.config/git/custom
      ansible.builtin.command: "grep -q config/git/custom {{ home }}/.config/git/config"
      register: git_include
      changed_when: false
      failed_when: false

    - name: Warn if include missing
      ansible.builtin.debug:
        msg: "~/.config/git/config lacks the include of ~/.config/git/custom; add: [include] path = ~/.config/git/custom"
      when: git_include.rc != 0

- name: Create git identity (one-time)
  when: not gitconfig.stat.exists
  block:
    - name: Prompt git user.name
      ansible.builtin.pause:
        prompt: "git user.name (leave empty to skip)"
      register: git_name

    - name: Prompt git user.email
      ansible.builtin.pause:
        prompt: "git user.email (leave empty to skip)"
      register: git_email

    - name: Write ~/.config/git/config
      ansible.builtin.copy:
        dest: "{{ home }}/.config/git/config"
        content: |
          {% if git_name.user_input or git_email.user_input %}
          [user]
          {% if git_name.user_input %}
          	name = {{ git_name.user_input }}
          {% endif %}
          {% if git_email.user_input %}
          	email = {{ git_email.user_input }}
          {% endif %}

          {% endif %}
          # shared settings managed by dotfiles (delta, catppuccin theme) - do not edit
          [include]
          	path = ~/.config/git/custom

    - name: Warn if identity left empty
      ansible.builtin.debug:
        msg: "created ~/.config/git/config without [user]; add user.name/user.email manually"
      when: not git_name.user_input or not git_email.user_input
```

- [ ] **Step 3: Verify**

```bash
cd playbooks
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --tags git
```

Expected: since `~/.config/git/config` exists on this machine, no prompts appear and the include check passes silently. Re-run: all `ok`.

---

### Task 8: `mpv` app — config + system script symlinks

**Files:**
- Move: `dotfiles/.config/mpv/` → `files/apps/mpv/.config/mpv/`
- Modify: `tasks/apps/mpv.yml`

- [ ] **Step 1: Move files**

```bash
mkdir -p playbooks/roles/software/files/apps/mpv/.config
mv dotfiles/.config/mpv playbooks/roles/software/files/apps/mpv/.config/
```

(The moved tree contains no `scripts/` dir — symlinks are created by the task below, exactly like the old `mpv_scripts` stage.)

- [ ] **Step 2: `tasks/apps/mpv.yml`**

```yaml
---
- name: Deploy mpv config
  ansible.builtin.copy:
    src: apps/mpv/
    dest: "{{ home }}/"

- name: Ensure mpv scripts dir
  ansible.builtin.file:
    path: "{{ home }}/.config/mpv/scripts"
    state: directory

- name: Link system mpv scripts (uosc / thumbfast / sponsorblock)
  ansible.builtin.file:
    src: "{{ item }}"
    dest: "{{ home }}/.config/mpv/scripts/"
    state: link
    force: true
  loop: "{{ query('ansible.builtin.fileglob', '/usr/share/mpv/scripts/*') }}"
```

- [ ] **Step 3: Verify**

```bash
cd playbooks
ansible-playbook site.yml --tags mpv
ls -la ~/.config/mpv/scripts/
```

Expected: symlinks for uosc/thumbfast/sponsorblock present; re-run all `ok`.

---

### Task 9: `fcitx5` app — config + rime data

**Files:**
- Move: `dotfiles/.config/fcitx5/` → `files/apps/fcitx5/.config/fcitx5/`
- Move: `dotfiles/.local/share/fcitx5/` → `files/apps/fcitx5/.local/share/fcitx5/`
- Modify: `tasks/apps/fcitx5.yml`

(The catppuccin fcitx5 **theme** is cloned from GitHub — that lives in the `settings` role, Task 14, matching the old `themes` stage.)

- [ ] **Step 1: Move files**

```bash
mkdir -p playbooks/roles/software/files/apps/fcitx5/.config \
         playbooks/roles/software/files/apps/fcitx5/.local/share
mv dotfiles/.config/fcitx5 playbooks/roles/software/files/apps/fcitx5/.config/
mv dotfiles/.local/share/fcitx5 playbooks/roles/software/files/apps/fcitx5/.local/share/
```

- [ ] **Step 2: `tasks/apps/fcitx5.yml`**

```yaml
---
- name: Deploy fcitx5 config and rime data
  ansible.builtin.copy:
    src: apps/fcitx5/
    dest: "{{ home }}/"
```

- [ ] **Step 3: Verify**

```bash
cd playbooks
ansible-playbook site.yml --tags fcitx5
ls ~/.config/fcitx5/profile ~/.local/share/fcitx5/rime/default.custom.yaml
```

---

### Task 10: `hyprland` app — hypr configs (templated) + dunst/rofi/satty + wallpaper

**Files:**
- Move: `dotfiles/.config/hypr/hypr{paper,idle,lock}.conf` → `files/apps/hyprland/.config/hypr/`
- Move: `dotfiles/.config/hypr/hyprland.lua` → `templates/apps/hyprland/hyprland.lua.j2` (then templated, Step 2)
- Move: `dotfiles/.config/{dunst,rofi,satty}` + `dotfiles/.local/share/rofi` → `files/apps/hyprland/…`
- Modify: `tasks/apps/hyprland.yml`

**Interfaces:**
- Consumes: `monitor`, `scale` (host_vars), `home`, `playbook_dir`.

- [ ] **Step 1: Move files**

```bash
mkdir -p playbooks/roles/software/files/apps/hyprland/.config/hypr \
         playbooks/roles/software/files/apps/hyprland/.local/share \
         playbooks/roles/software/templates/apps/hyprland
mv dotfiles/.config/hypr/hyprpaper.conf dotfiles/.config/hypr/hypridle.conf dotfiles/.config/hypr/hyprlock.conf \
   playbooks/roles/software/files/apps/hyprland/.config/hypr/
mv dotfiles/.config/hypr/hyprland.lua playbooks/roles/software/templates/apps/hyprland/hyprland.lua.j2
mv dotfiles/.config/dunst dotfiles/.config/rofi dotfiles/.config/satty \
   playbooks/roles/software/files/apps/hyprland/.config/
mv dotfiles/.local/share/rofi playbooks/roles/software/files/apps/hyprland/.local/share/
```

- [ ] **Step 2: Templatize `hyprland.lua.j2`** — replace the monitor block (currently lines 9-13):

```lua
-- Use `hyprctl monitors` to check interface names; adjust as needed
-- Scale 1.25; external monitors usually use 1
hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = 1.25 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
-- hl.monitor({ output = "DP-2",  mode = "preferred", position = "0x0",    scale = 1.25 })
```

with:

```lua
-- Monitor/scale come from playbooks/inventory/host_vars/<host>.yml
hl.monitor({ output = "{{ monitor }}", mode = "preferred", position = "0x0", scale = {{ scale }} })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
```

Do not reformat anything else in the file (no stylua; 4-space indent, aligned `=`).

- [ ] **Step 3: `tasks/apps/hyprland.yml`**

```yaml
---
- name: Deploy hyprland.lua (rendered from host_vars)
  ansible.builtin.template:
    src: apps/hyprland/hyprland.lua.j2
    dest: "{{ home }}/.config/hypr/hyprland.lua"

- name: Deploy hypr ecosystem configs (hyprpaper/idle/lock, dunst, rofi, satty)
  ansible.builtin.copy:
    src: apps/hyprland/
    dest: "{{ home }}/"

- name: Deploy wallpaper
  ansible.builtin.copy:
    src: "{{ playbook_dir }}/../assets/colin-watts.jpg"
    dest: "{{ home }}/.config/hypr/wallpaper.jpg"
```

- [ ] **Step 4: Verify**

```bash
cd playbooks
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --tags hyprland
luac -p ~/.config/hypr/hyprland.lua
grep 'hl.monitor' ~/.config/hypr/hyprland.lua
```

Expected: `luac -p` passes; monitor line shows `output = "DP-1"` and `scale = 1.25`.

---

### Task 11: `waybar` app — config (templated) + style + popup scripts

**Files:**
- Move: `dotfiles/.config/waybar/config.jsonc` → `templates/apps/waybar/config.jsonc.j2`
- Move: `dotfiles/.config/waybar/style.css` → `files/apps/waybar/.config/waybar/style.css`
- Move: `dotfiles/.local/bin/{weather.py,calendar.py,waybar_geom.py}` → `files/apps/waybar/.local/bin/`
- Delete: `dotfiles/.local/bin/__pycache__/` (stale bytecode, not migrated)
- Modify: `tasks/apps/waybar.yml`

**Interfaces:**
- Consumes: `net_interface` (host_vars). Notifies handler `Reload waybar` (Task 3, exact name).

- [ ] **Step 1: Move files**

```bash
mkdir -p playbooks/roles/software/files/apps/waybar/.config/waybar \
         playbooks/roles/software/files/apps/waybar/.local/bin \
         playbooks/roles/software/templates/apps/waybar
mv dotfiles/.config/waybar/config.jsonc playbooks/roles/software/templates/apps/waybar/config.jsonc.j2
mv dotfiles/.config/waybar/style.css playbooks/roles/software/files/apps/waybar/.config/waybar/
mv dotfiles/.local/bin/weather.py dotfiles/.local/bin/calendar.py dotfiles/.local/bin/waybar_geom.py \
   playbooks/roles/software/files/apps/waybar/.local/bin/
rm -rf dotfiles/.local/bin/__pycache__
```

- [ ] **Step 2: Templatize `config.jsonc.j2`** — replace `"interface": "wlp6s0"` (line 41) with:

```json
        "interface": "{{ net_interface }}",
```

- [ ] **Step 3: `tasks/apps/waybar.yml`**

```yaml
---
- name: Deploy waybar config (rendered from host_vars)
  ansible.builtin.template:
    src: apps/waybar/config.jsonc.j2
    dest: "{{ home }}/.config/waybar/config.jsonc"
  notify: Reload waybar

- name: Deploy waybar style + popup scripts (weather.py / calendar.py / waybar_geom.py)
  ansible.builtin.copy:
    src: apps/waybar/
    dest: "{{ home }}/"
    mode: preserve
  notify: Reload waybar
```

- [ ] **Step 4: Verify**

```bash
cd playbooks
ansible-playbook site.yml --tags waybar
python -c "import json; json.load(open('$HOME/.config/waybar/config.jsonc'))" 2>/dev/null || grep -n '"interface"' ~/.config/waybar/config.jsonc
ls -la ~/.local/bin/weather.py ~/.local/bin/waybar_geom.py
grep -n "LD_PRELOAD" ~/.local/bin/weather.py ~/.local/bin/calendar.py
```

Expected: `"interface": "wlp6s0"` in deployed file; scripts executable; LD_PRELOAD re-exec block intact in both popup scripts (do not remove — gtk4-layer-shell must preload before libwayland-client). Note: config.jsonc may contain comments (JSONC) — the python json check may fail; the grep fallback confirms the template rendered.

---

### Task 12: `web-apps` + `gui-apps` — .desktop files, icons, native-app overrides

**Files:**
- Move: `dotfiles/.local/share/applications/{deepseek,github,gmail,kimi}.desktop` → `files/apps/web-apps/.local/share/applications/`
- Move: `dotfiles/.local/share/icons/hicolor/` → `files/apps/web-apps/.local/share/icons/hicolor/`
- Move: `dotfiles/.local/share/applications/wechat.desktop` → `templates/apps/gui-apps/wechat.desktop.j2`
- Move: `dotfiles/.config/{pcmanfm,zathura}`, `dotfiles/.config/mimeapps.list` → `files/apps/gui-apps/.config/…`
- Modify: `tasks/apps/web-apps.yml`, `tasks/apps/gui-apps.yml`

**Interfaces:**
- Consumes: `scale` (host_vars, gui-apps). Notifies `Update desktop database`, `Update icon cache` (Task 3, exact names).

- [ ] **Step 1: Move files**

```bash
mkdir -p playbooks/roles/software/files/apps/web-apps/.local/share/applications \
         playbooks/roles/software/files/apps/web-apps/.local/share/icons \
         playbooks/roles/software/files/apps/gui-apps/.config \
         playbooks/roles/software/templates/apps/gui-apps
mv dotfiles/.local/share/applications/deepseek.desktop dotfiles/.local/share/applications/github.desktop \
   dotfiles/.local/share/applications/gmail.desktop dotfiles/.local/share/applications/kimi.desktop \
   playbooks/roles/software/files/apps/web-apps/.local/share/applications/
mv dotfiles/.local/share/icons/hicolor playbooks/roles/software/files/apps/web-apps/.local/share/icons/
mv dotfiles/.local/share/applications/wechat.desktop playbooks/roles/software/templates/apps/gui-apps/wechat.desktop.j2
mv dotfiles/.config/pcmanfm dotfiles/.config/zathura playbooks/roles/software/files/apps/gui-apps/.config/
mv dotfiles/.config/mimeapps.list playbooks/roles/software/files/apps/gui-apps/.config/
```

- [ ] **Step 2: Templatize `wechat.desktop.j2`** — replace `Exec=env QT_SCALE_FACTOR=1.25 /opt/wechat/wechat %U` with:

```desktop
Exec=env QT_SCALE_FACTOR={{ scale }} /opt/wechat/wechat %U
```

(Keep the existing comment about XWayland fractional scaling; append: `-- scale comes from host_vars`.)

- [ ] **Step 3: Task files**

`tasks/apps/web-apps.yml`:
```yaml
---
- name: Deploy Chrome web apps (.desktop + hicolor icons)
  ansible.builtin.copy:
    src: apps/web-apps/
    dest: "{{ home }}/"
  notify:
    - Update desktop database
    - Update icon cache
```

`tasks/apps/gui-apps.yml`:
```yaml
---
- name: Deploy wechat desktop override (QT_SCALE_FACTOR from host_vars)
  ansible.builtin.template:
    src: apps/gui-apps/wechat.desktop.j2
    dest: "{{ home }}/.local/share/applications/wechat.desktop"
  notify: Update desktop database

- name: Deploy native GUI app configs (pcmanfm, zathura, mimeapps)
  ansible.builtin.copy:
    src: apps/gui-apps/
    dest: "{{ home }}/"
```

- [ ] **Step 4: Verify**

```bash
cd playbooks
ansible-playbook site.yml --tags web-apps,gui-apps
grep QT_SCALE_FACTOR ~/.local/share/applications/wechat.desktop   # expect 1.25
ls ~/.local/share/applications/ ~/.local/share/icons/hicolor/256x256/apps/
```

Expected: 5 .desktop files deployed (4 web + wechat override); 4 icons; handlers ran without failure.

---

### Task 13: `dev` app — languages tooling, zed/pi configs, try-cli, user dirs

**Files:**
- Move: `dotfiles/.config/zed/` → `files/apps/dev/.config/zed/`
- Move: `dotfiles/.pi/` → `files/apps/dev/.pi/`
- Move: `dotfiles/.config/systemd/user/dsh-web.service` → `files/apps/dev/.config/systemd/user/dsh-web.service`
- Move: `dotfiles/.config/user-dirs.conf`, `dotfiles/.config/user-dirs.dirs` → `files/apps/dev/.config/`
- Create: `files/apps/dev/.config/zsh/conf.d/{15-dev-aliases,60-try}.zsh`, `files/apps/dev/.local/bin/try`
- Modify: `tasks/apps/dev.yml`

**Interfaces:**
- Consumes: `npm_globals`, `home`, `uid`. Produces: `~/.config/systemd/user/dsh-web.service` (enabled by `services` role, Task 15).

- [ ] **Step 1: Move + create files**

```bash
mkdir -p playbooks/roles/software/files/apps/dev/.config/systemd/user \
         playbooks/roles/software/files/apps/dev/.config/zsh/conf.d \
         playbooks/roles/software/files/apps/dev/.local/bin
mv dotfiles/.config/zed playbooks/roles/software/files/apps/dev/.config/
mv dotfiles/.pi playbooks/roles/software/files/apps/dev/
mv dotfiles/.config/systemd/user/dsh-web.service playbooks/roles/software/files/apps/dev/.config/systemd/user/
mv dotfiles/.config/user-dirs.conf dotfiles/.config/user-dirs.dirs playbooks/roles/software/files/apps/dev/.config/
```

`15-dev-aliases.zsh`:
```zsh
# dev tool aliases (owned by: dev app)
alias zed=zeditor
```

`60-try.zsh`:
```zsh
# try — experiment in isolated dirs (git clone in ~/.local/share/try-cli; owned by: dev app)
(( $+commands[try] )) && eval "$(command try init ~/src/tries)"
```

`.local/bin/try` (mode 0755 — set in Step 3 after the move completes, and preserved by `mode: preserve` on deploy):
```sh
#!/bin/sh
exec ruby "$HOME/.local/share/try-cli/try.rb" "$@"
```

- [ ] **Step 2: `tasks/apps/dev.yml`** (absorbs `scripts/install-try-cli.sh` and the old `post` stage's tooling parts):

```yaml
---
- name: Deploy dev files (zed, pi, dsh-web unit, user-dirs, zsh fragments, try wrapper)
  ansible.builtin.copy:
    src: apps/dev/
    dest: "{{ home }}/"
    mode: preserve

- name: Set npm global prefix to ~/.local
  ansible.builtin.command: "npm config set prefix {{ home }}/.local"
  register: npm_prefix
  changed_when: false
  failed_when: false

- name: Install npm global tools
  ansible.builtin.command: "npm i -g {{ npm_globals | join(' ') }}"
  register: npm_install
  changed_when: false
  failed_when: false

- name: Warn on npm global install failure
  ansible.builtin.debug:
    msg: "npm global install failed, do it manually later: npm i -g {{ npm_globals | join(' ') }}"
  when: npm_install is failed

- name: Set rustup default toolchain
  ansible.builtin.command: rustup default stable
  register: rustup_default
  changed_when: "'info: using existing' not in rustup_default.stdout"
  failed_when: false

- name: Install try-cli (tobi/try, Ruby)
  ansible.builtin.git:
    repo: https://github.com/tobi/try.git
    dest: "{{ home }}/.local/share/try-cli"
    depth: 1
    update: false
  register: try_clone
  failed_when: false

- name: Warn on try-cli clone failure
  ansible.builtin.debug:
    msg: "try-cli clone failed, install manually later: https://github.com/tobi/try"
  when: try_clone is failed

- name: Update xdg user directories
  ansible.builtin.command: xdg-user-dirs-update
  changed_when: false
  failed_when: false

- name: Create working directories
  ansible.builtin.file:
    path: "{{ home }}/{{ item }}"
    state: directory
  loop:
    - Projects
    - Pictures/mpv
    - src/tries

- name: Build bat theme cache
  ansible.builtin.command: bat cache --build
  changed_when: false
  failed_when: false
```

(`npm i -g` and `rustup` have no cheap idempotence check; they are marked `changed_when: false`/`failed_when: false` and simply re-run — same guarantee level as the old script.)

- [ ] **Step 3: Make the try wrapper executable in the repo and verify**

```bash
chmod 0755 playbooks/roles/software/files/apps/dev/.local/bin/try
cd playbooks
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --tags dev
ls -la ~/.local/bin/try ~/.config/systemd/user/dsh-web.service
zsh -n roles/software/files/apps/dev/.config/zsh/conf.d/*.zsh
```

---

### Task 14: `settings` role — fonts + theming + gsettings + SDDM

**Files:**
- Move: `dotfiles/.config/gtk-3.0/`, `dotfiles/.config/gtk-4.0/`, `dotfiles/.gtkrc-2.0`, `dotfiles/.config/Kvantum/`, `dotfiles/.config/fontconfig/` → `playbooks/roles/settings/files/…`
- Create: `playbooks/roles/settings/tasks/main.yml`
- Create: `playbooks/roles/settings/handlers/main.yml`

**Interfaces:**
- Consumes: `home`, `uid`, `gtk_theme`, `icon_theme`, `gtk_font`, `playbook_dir`. Handler `Refresh font cache` defined **here** (settings role), same semantics as the software one — notified by GTK4 symlink tasks.

- [ ] **Step 1: Move files** (settings role has its own `files/` root, home-relative):

```bash
mkdir -p playbooks/roles/settings/files/.config
mv dotfiles/.config/gtk-3.0 dotfiles/.config/gtk-4.0 dotfiles/.config/Kvantum dotfiles/.config/fontconfig \
   playbooks/roles/settings/files/.config/
mv dotfiles/.gtkrc-2.0 playbooks/roles/settings/files/
```

Note: `files/.config/gtk-4.0/` contains only `settings.ini` — the Colloid symlinks (`assets`, `gtk.css`, `gtk-dark.css`) are created by tasks below, not stored in the repo.

- [ ] **Step 2: `roles/settings/handlers/main.yml`**

```yaml
---
- name: Refresh font cache
  ansible.builtin.command: fc-cache -f
  failed_when: false
  listen: Refresh font cache
```

- [ ] **Step 3: `roles/settings/tasks/main.yml`** (absorbs `scripts/install-fcitx5-theme.sh` and the old `themes` stage):

```yaml
---
# fcitx5 catppuccin theme (cloned from GitHub; skipped when already present)
- name: Check fcitx5 theme dir
  ansible.builtin.stat:
    path: "{{ home }}/.local/share/fcitx5/themes/catppuccin-mocha-blue"
  register: fcitx5_theme

- name: Install fcitx5 catppuccin theme
  when: not fcitx5_theme.stat.exists
  block:
    - name: Create temp dir
      ansible.builtin.tempfile:
        state: directory
        suffix: .fcitx5-theme
      register: fcitx5_tmp

    - name: Clone catppuccin/fcitx5
      ansible.builtin.git:
        repo: https://github.com/catppuccin/fcitx5.git
        dest: "{{ fcitx5_tmp.path }}/fcitx5"
        depth: 1

    - name: Copy catppuccin-mocha-blue theme
      ansible.builtin.copy:
        src: "{{ fcitx5_tmp.path }}/fcitx5/src/catppuccin-mocha-blue"
        dest: "{{ home }}/.local/share/fcitx5/themes/catppuccin-mocha-blue"
        remote_src: true

    - name: Enable rounded corners
      ansible.builtin.command: "bash {{ fcitx5_tmp.path }}/fcitx5/enable-rounded.sh"
      args:
        chdir: "{{ home }}/.local/share/fcitx5/themes/catppuccin-mocha-blue"
      failed_when: false

    - name: Clean up
      ansible.builtin.file:
        path: "{{ fcitx5_tmp.path }}"
        state: absent

# GTK / Qt static config files
- name: Deploy GTK/Kvantum/fontconfig files
  ansible.builtin.copy:
    src: files/
    dest: "{{ home }}/"
  notify: Refresh font cache

# GTK4 / Libadwaita theme links
- name: Locate Colloid theme
  ansible.builtin.stat:
    path: "{{ item }}"
  loop:
    - "{{ home }}/.themes/Colloid-Dark-Catppuccin"
    - /usr/share/themes/Colloid-Dark-Catppuccin
  register: colloid_dirs

- name: Resolve Colloid theme path
  ansible.builtin.set_fact:
    colloid_theme: "{{ item.item }}"
  loop: "{{ colloid_dirs.results }}"
  when: item.stat.exists
  loop_control:
    label: "{{ item.item }}"

- name: Warn if Colloid theme missing
  ansible.builtin.debug:
    msg: "Colloid-Dark-Catppuccin theme not found, skipping GTK4 links (AUR package not installed?)"
  when: colloid_theme is not defined

- name: Link GTK4 theme into ~/.config/gtk-4.0
  when: colloid_theme is defined
  ansible.builtin.file:
    src: "{{ colloid_theme }}/gtk-4.0/{{ item }}"
    dest: "{{ home }}/.config/gtk-4.0/{{ item }}"
    state: link
    force: true
  loop:
    - assets
    - gtk.css
    - gtk-dark.css

# gsettings (portal takes precedence over settings.ini); may fail on headless runs — warn only
- name: Apply GNOME interface settings
  ansible.builtin.command: "gsettings set org.gnome.desktop.interface {{ item.key }} '{{ item.value }}'"
  environment:
    DBUS_SESSION_BUS_ADDRESS: "unix:path=/run/user/{{ uid }}/bus"
  loop:
    - { key: gtk-theme, value: "{{ gtk_theme }}" }
    - { key: icon-theme, value: "{{ icon_theme }}" }
    - { key: color-scheme, value: prefer-dark }
    - { key: font-name, value: "{{ gtk_font }}" }
  changed_when: false
  failed_when: false
  when: colloid_theme is defined

# SDDM catppuccin theme + wallpaper
- name: Locate SDDM catppuccin theme
  become: true
  ansible.builtin.find:
    paths: /usr/share/sddm/themes
    patterns: "catppuccin-mocha-*"
    file_type: directory
  register: sddm_themes

- name: Warn if SDDM theme missing
  ansible.builtin.debug:
    msg: "catppuccin-mocha SDDM theme dir not found, skipping (AUR package not installed?)"
  when: sddm_themes.matched == 0

- name: Configure SDDM theme
  when: sddm_themes.matched > 0
  block:
    - name: Prefer catppuccin-mocha-blue when present
      ansible.builtin.set_fact:
        sddm_theme: "{{ (sddm_themes.files | selectattr('path', 'search', 'catppuccin-mocha-blue$') | list | first).path
                        if (sddm_themes.files | selectattr('path', 'search', 'catppuccin-mocha-blue$') | list | length) > 0
                        else sddm_themes.files[0].path }}"

    - name: Copy wallpaper into SDDM theme
      become: true
      ansible.builtin.copy:
        src: "{{ playbook_dir }}/../assets/colin-watts.jpg"
        dest: "{{ sddm_theme }}/backgrounds/wallpaper.jpg"

    - name: Point theme background at wallpaper
      become: true
      ansible.builtin.replace:
        path: "{{ sddm_theme }}/theme.conf"
        regexp: "^(?i)background=.*"
        replace: 'Background="backgrounds/wallpaper.jpg"'

    - name: Write /etc/sddm.conf.d/10-theme.conf
      become: true
      ansible.builtin.copy:
        dest: /etc/sddm.conf.d/10-theme.conf
        content: |
          [Theme]
          Current={{ sddm_theme | basename }}
        mode: "0644"
```

- [ ] **Step 4: Verify**

```bash
cd playbooks
ansible-playbook site.yml --syntax-check
ansible-lint roles/settings/tasks/main.yml || true
ansible-playbook site.yml --tags settings --ask-become-pass   # hand to user (SDDM needs sudo)
ls -la ~/.config/gtk-4.0/
gsettings get org.gnome.desktop.interface gtk-theme
```

Expected: gtk-4.0 contains settings.ini (file) + assets/gtk.css/gtk-dark.css (symlinks into Colloid); gsettings returns `'Colloid-Dark-Catppuccin'`.

---

### Task 15: `services` role — systemd units

**Files:**
- Create: `playbooks/roles/services/tasks/main.yml`
- Modify: `playbooks/inventory/group_vars/all.yml` (append unit lists)

**Interfaces:**
- Consumes: `system_units`, `user_units` (new group_vars), `home`, `uid`. Consumes `~/.config/systemd/user/dsh-web.service` deployed by Task 13.

- [ ] **Step 1: Append to `group_vars/all.yml`**

```yaml
system_units:
  - NetworkManager
  - bluetooth
  - sshd
  - fail2ban
  - cups.socket
  - avahi-daemon
  - udisks2
  - earlyoom
  - fstrim.timer
  - docker.socket
  - libvirtd.socket
  - sddm
user_units:
  - pipewire
  - pipewire-pulse
  - wireplumber
```

- [ ] **Step 2: `roles/services/tasks/main.yml`**

```yaml
---
- name: Enable system services
  become: true
  ansible.builtin.systemd:
    name: "{{ item }}"
    enabled: true
    state: started
  loop: "{{ system_units }}"
  register: sys_services
  failed_when: false

- name: Warn about failed system services
  ansible.builtin.debug:
    msg: "enable failed: {{ item.item }}"
  loop: "{{ sys_services.results }}"
  when: item is failed
  loop_control:
    label: "{{ item.item }}"

- name: Enable user audio services
  ansible.builtin.systemd:
    name: "{{ item }}"
    enabled: true
    state: started
    scope: user
  environment:
    XDG_RUNTIME_DIR: "/run/user/{{ uid }}"
  loop: "{{ user_units }}"
  failed_when: false

# dsh web (DeepSeek Harness) user service — unit file deployed by the dev app;
# may fail on a headless run with no user manager, that's ok
- name: Check dsh-web unit file
  ansible.builtin.stat:
    path: "{{ home }}/.config/systemd/user/dsh-web.service"
  register: dsh_unit

- name: Enable dsh-web user service
  when: dsh_unit.stat.exists
  block:
    - name: Reload user systemd
      ansible.builtin.command: systemctl --user daemon-reload
      environment:
        XDG_RUNTIME_DIR: "/run/user/{{ uid }}"
      failed_when: false

    - name: Enable dsh-web
      ansible.builtin.systemd:
        name: dsh-web.service
        enabled: true
        state: started
        scope: user
      environment:
        XDG_RUNTIME_DIR: "/run/user/{{ uid }}"
      register: dsh_svc
      failed_when: false

    - name: Warn on dsh-web failure
      ansible.builtin.debug:
        msg: "dsh web service failed to start — check: journalctl --user -u dsh-web -e"
      when: dsh_svc is failed

- name: Warn if dsh-web unit missing
  ansible.builtin.debug:
    msg: "dsh-web.service not found (dev app not run?); skipping user service enable"
  when: not dsh_unit.stat.exists
```

- [ ] **Step 3: Verify**

```bash
cd playbooks
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --tags services --ask-become-pass   # hand to user
systemctl is-enabled NetworkManager sddm docker.socket
systemctl --user is-enabled pipewire wireplumber
```

Expected: all `enabled`; re-run reports no changes.

---

### Task 16: Cutover — full verification, delete legacy, rewrite docs

**Files:**
- Delete: `install.sh`, `scripts/`, `packages/`, `dotfiles/`
- Modify: `AGENTS.md` (full rewrite below)
- Modify: `README.md`, `README.zh.md`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Sanity — dotfiles/ must be empty of content before deletion**

```bash
find dotfiles -type f
```

Expected: no output (all 73 files moved in Tasks 4-13; `__pycache__` deleted in Task 11). If anything remains, stop and assign it to an app before continuing.

- [ ] **Step 2: Full run (user executes — needs sudo + possible git identity is already set)**

```bash
cd playbooks
ansible-playbook site.yml --ask-become-pass
```

Expected: completes without failures; immediate re-run shows changes only on the known noisy tasks (`update_cache` pacman sync, `changed_when: false`-suppressed command tasks report ok).

- [ ] **Step 3: Fresh-shell smoke test**

Open a new kitty window; verify: prompt loads, `y`, `lg`, `zed` aliases work, Ctrl+R is atuin, syntax highlighting active. Open waybar weather popup and clock popup once (gtk4-layer-shell surfaces must appear below the waybar module, transparent background). Lock screen via hypridle path is untouched.

- [ ] **Step 4: Delete legacy**

```bash
rm -rf install.sh scripts packages dotfiles
```

- [ ] **Step 5: Rewrite `AGENTS.md`** — full replacement:

````markdown
# AGENTS.md

Personal Arch Linux + Hyprland bootstrap, managed by Ansible. Not an
application: no build, no automated tests, no git history. Docs and code
comments are in English. Commit messages are in English.

## Verification

- `cd playbooks && ansible-playbook site.yml --syntax-check` and `ansible-lint`
  are the static checks; `luac -p` applies to the **rendered**
  `~/.config/hypr/hyprland.lua`, not the `.j2` template.
- Do NOT run stylua on `hyprland.lua.j2` — default stylua (tabs) would
  reformat the whole file; existing style is 4-space indent with aligned `=`.
- The playbook is designed to run on this machine (it replaced install.sh):
  `cd playbooks && ansible-playbook site.yml --ask-become-pass`, or a subset
  via `--tags <app>` (e.g. `--tags waybar`). NEVER copy files from
  `playbooks/roles/**/files/` into `$HOME` by hand — deploy via the playbook.

## Layout

- `playbooks/` — the whole Ansible project. Run all ansible commands from here.
  - `site.yml` — single entrypoint, runs roles `base → software → settings → services`.
  - `inventory/hosts.ini` — host alias `desktop` (connection=local); add future
    machines here plus a matching `host_vars/<name>.yml`.
  - `inventory/group_vars/all.yml` — shared vars (home, uid, timezone, theme
    names, npm globals, systemd unit lists).
  - `inventory/host_vars/desktop.yml` — machine vars: `monitor`, `scale`,
    `net_interface`. Consumed by the hyprland.lua / waybar / wechat templates.
  - `roles/base` — layer 1: preflight asserts, timezone, locale, zram, sshd
    hardening, user groups, default shell.
  - `roles/software` — layer 2: packages + per-app config. `tasks/main.yml`
    includes `apps/_pacman.yml → apps/yay.yml → apps/_aur.yml` FIRST (hard
    order constraint: yay needs base-devel+git, _aur needs yay), then one
    `apps/<app>.yml` per application, each tagged with the app name.
    All official packages live in `_pacman.yml`, all AUR packages in
    `_aur.yml` (warn-and-continue per package); app files only deploy config,
    user services, and zsh fragments. App static files live in
    `files/apps/<app>/` mirroring the $HOME-relative path (deployed by a
    single `copy: src=apps/<app>/ dest={{ home }}/`); templates in
    `templates/apps/<app>/`.
  - `roles/settings` — layer 3: fcitx5 catppuccin theme, GTK/Qt/Kvantum/font
    config files, GTK4 Colloid symlinks, gsettings, SDDM theme + wallpaper.
  - `roles/services` — layer 4: system systemd units + user pipewire units +
    dsh-web user service.
- `assets/colin-watts.jpg` — one wallpaper used twice: SDDM theme background
  and `~/.config/hypr/wallpaper.jpg` (referenced by `hyprpaper.conf`).
- README is dual-language: `README.md` English (GitHub homepage),
  `README.zh.md` Chinese mirror. Keep both in sync.

## Gotchas

- Hyprland config is **Lua** — Hyprland 0.55+ dropped hyprlang. Do not create
  or edit a `hyprland.conf`.
- Hyprland 0.55+ rejects legacy `hyprctl dispatch <name> <args>` strings; use
  the Lua DSL (`hl.dsp.dpms({ action = "disable" })`). Known casualties: dpms
  in `hypridle.conf`, and waybar 0.15.0's `hyprland/workspaces`
  click-to-switch (fixed in waybar master; resolves with the 0.16 release —
  don't "fix" it via config or by switching to waybar-git unless asked).
- The weather popup (`weather.py --popup`) and clock popup (`calendar.py`)
  are fullscreen transparent **gtk4-layer-shell** surfaces — position, CSS
  rounded corners, and click-outside-to-close live inside the scripts. Do not
  add Hyprland window_rules for them, do not reintroduce focus-out dismissal,
  and do not remove the `LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so` re-exec
  block (gtk4-layer-shell must load before libwayland-client). App CSS that
  must override the Colloid theme needs `Gtk.STYLE_PROVIDER_PRIORITY_USER`
  (theme loads at USER priority 800). Both popups anchor under their waybar
  module via AT-SPI geometry through `waybar_geom.py`.
- Machine differences live in `host_vars/` — monitor `DP-1` @ scale 1.25,
  waybar `network.interface = wlp6s0`, wechat `QT_SCALE_FACTOR`. Don't
  hardcode them back into templates.
- `~/.config/git/config` is user-owned — created once (interactive
  user.name/user.email prompt on first run), never overwritten; it includes
  the managed `~/.config/git/custom` (delta + catppuccin).
- gsettings over a guessed `DBUS_SESSION_BUS_ADDRESS` can fail on a
  headless/tty run and only warns; that's expected.
- `~/.local/bin/try` wraps a git clone of `tobi/try` (Ruby). The AUR package
  named `try` is a different tool — don't swap it in.
- Everything themes to catppuccin-mocha (blue accent). New config should match.
- User-facing UI text stays Chinese (desktop entry names/comments, waybar
  labels, hyprlock placeholder). Everything else — comments, docs, playbook
  task names and output — is English.
- `.zshrc` is a skeleton sourcing `~/.config/zsh/conf.d/*.zsh` in lexical
  order; each fragment is owned by its app (`files/apps/<app>/.config/zsh/conf.d/`).
  `99-syntax-highlighting.zsh` must stay last.
````

- [ ] **Step 6: Rewrite READMEs** — `README.md` (English) structure: intro (personal Arch+Hyprland config managed by Ansible), screenshot/wallpaper note as before, **Usage** section with exact commands:

```bash
cd playbooks
ansible-playbook site.yml --ask-become-pass              # full setup
ansible-playbook site.yml --tags waybar --ask-become-pass # one app
ansible-playbook site.yml --list-tasks                   # what's available
```

plus a Layout section mirroring the AGENTS.md layout (condensed), and the machine-vars note (edit `host_vars/desktop.yml` for monitor/scale/NIC). `README.zh.md` is the Chinese mirror of the same content. Keep badges/license header from the current READMEs if present — read them before rewriting.

- [ ] **Step 7: Final static checks**

```bash
cd playbooks
ansible-playbook site.yml --syntax-check
ansible-lint site.yml || true
luac -p ~/.config/hypr/hyprland.lua
ls install.sh scripts packages dotfiles 2>&1   # expect "No such file or directory"
```

---

## Self-Review Notes

- Spec coverage: base (T2), software infra + 12 apps (T3-T13), settings (T14), services (T15), templates/host_vars (T1, T10-T12), zsh modularization (T4/5/6/13), migration + docs (T16). All spec sections map to a task.
- Intentional spec deviations: git identity uses conditional `pause` instead of `vars_prompt` (would prompt every run); `core.yml` dropped (base packages are comment groups inside `_pacman.yml`); folder named `playbooks/` (user amendment after spec).
- Type consistency: handler names (`Reload waybar`, `Update desktop database`, `Update icon cache`, `Refresh font cache`), vars (`home`, `uid`, `monitor`, `scale`, `net_interface`, `npm_globals`, `system_units`, `user_units`, `gtk_theme`, `icon_theme`, `gtk_font`) are used identically across tasks.

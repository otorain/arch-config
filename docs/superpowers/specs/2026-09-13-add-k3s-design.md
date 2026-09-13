# Add k3s to Software List — Design

**Date:** 2026-09-13

## Problem

k3s is not in the software list. The user wants a persistent single-node
Kubernetes cluster on this desktop: package installed, `k3s.service`
enabled+started, and passwordless user access via `kubectl`.

## Choices (confirmed with user)

- **Package:** `k3s-bin` (AUR) — official repos carry no k3s; the AUR `k3s`
  source package builds for hours. `k3s-bin` ships `k3s.service`
  (`ExecStart=/usr/bin/k3s server`, reads `/etc/rancher/k3s/config.yaml` by
  default) plus `/etc/systemd/system/k3s.service.env` (left untouched).
- **Mode:** persistent single-node server — add `k3s` to `system_units`.
- **User access:** world-readable kubeconfig + env var, NOT copying
  `/etc/rancher/k3s/k3s.yaml` into `~/.kube/config` (no wait-for-generation
  task, immune to cert regeneration). Security trade-off (any local user can
  read cluster-admin creds) is acceptable on a single-user desktop.
- **Companions:** `kubectl`, `helm`, `k9s` — all official extra repo.

## Design

1. **`playbooks/roles/software/tasks/_aur.yml`** — new group:

   ```yaml
   # === Kubernetes ===
   - k3s-bin
   ```

2. **`playbooks/roles/software/tasks/_pacman.yml`** — new group (placed
   after `=== Virtualization / Containers ===`):

   ```yaml
   # === Kubernetes ===
   - kubectl
   - helm
   - k9s
   ```

3. **New app `k3s`** — `playbooks/roles/software/tasks/k3s.yml` plus the
   matching include in `main.yml` (alphabetical: between `kimi` and
   `kitty`), following the `apply: tags:` + outer `tags:` pattern:

   ```yaml
   - name: Deploy k3s server config
     become: true
     ansible.builtin.copy:
       src: k3s/config.yaml
       dest: /etc/rancher/k3s/config.yaml
       owner: root
       group: root
       mode: "0644"
   ```

   `playbooks/roles/software/files/k3s/config.yaml`:

   ```yaml
   write-kubeconfig-mode: "644"
   ```

   Ordering guarantee: software runs before services, so the config is in
   place before `k3s.service` first starts — the very first generated
   `k3s.yaml` is already mode 644.

4. **zsh fragment** `playbooks/roles/software/files/zsh/25-k3s.zsh`
   (number slots between `20-zoxide` and `30-fzf`; deployed centrally by
   `zsh.yml`'s fileglob — NOT by the k3s app):

   ```zsh
   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
   ```

5. **`playbooks/inventory/group_vars/all.yml`** — append `k3s` to
   `system_units` (services role enables+starts it).

6. **Docs sync** — AGENTS.md: 29 → 30 apps, 14 → 15 zsh fragments;
   README.md / README.zh.md: add k3s to the app lists (both languages).

## Verification

- `cd playbooks && ansible-playbook site.yml --syntax-check`
- `cd playbooks && ansible-lint`
- `cd playbooks && ansible-playbook site.yml --check --tags k3s,zsh,packages,aur,services` (dry run)
- Real run on this machine: `ansible-playbook site.yml --ask-become-pass`;
  afterwards `kubectl get nodes` shows the node Ready (allow ~1 min for the
  first `k3s.yaml` generation).

## Out of scope

- Agent/multi-node setup (`k3s.service.env` stays package-owned).
- Helm repos, k9s skin config, kubectl completions beyond what the
  `kubectl` package ships.
- Merging remote clusters into KUBECONFIG (append to the env list when
  needed later).
- Conflict with docker: none — k3s uses its bundled containerd
  (`/run/k3s/containerd`), docker keeps only its socket enabled.

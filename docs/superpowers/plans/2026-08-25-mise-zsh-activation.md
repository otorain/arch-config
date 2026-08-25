# Mise Zsh Activation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the installed `mise` into zsh via a managed conf.d fragment (shims on PATH + activate hook).

**Architecture:** Add one new numbered zsh fragment `65-mise.zsh` to `roles/software/files/zsh/`; the existing `with_fileglob: "zsh/[0-9]*.zsh"` in `zsh.yml` deploys it with zero task changes. The fragment sets `~/.local/share/mise/shims` on PATH (mise 2026.8.10's `activate` does not do this) and evals `mise activate zsh` guarded by `(( $+commands[mise] ))`, matching the style of `60-try.zsh`.

**Tech Stack:** Ansible (zsh app role), zsh conf.d fragment convention (05–99).

## Global Constraints

- No new tasks/includes — the fragment must be picked up by the existing fileglob.
- Style: 4-space conventions, guard `(( $+commands[...] )) && eval "..."`, comment header `# mise — <what> (owned by: zsh)`.
- `~/.zshrc` must NOT be modified (user-owned, deployed once).
- Do not run stylua; do not touch templates; no new packages in `_pacman.yml`/`_aur.yml`.
- Commit message in English per repo convention.

---

### Task 1: Add mise zsh fragment + docs count

**Files:**
- Create: `playbooks/roles/software/files/zsh/65-mise.zsh`
- Modify: `AGENTS.md` (fragment count 13 → 14 in the zsh bullet)

**Interfaces:**
- Consumes: nothing (existing zsh role infrastructure, tags `zsh`).
- Produces: `~/.config/zsh/conf.d/65-mise.zsh` — exports `PATH` with mise shims and evals the zsh activate hook. Later tasks need nothing from this.

- [ ] **Step 1: Create the fragment**

Create `playbooks/roles/software/files/zsh/65-mise.zsh`:

```zsh
# mise — dev tool version manager (owned by: zsh)
export PATH="$HOME/.local/share/mise/shims:$PATH"
(( $+commands[mise] )) && eval "$(mise activate zsh)"
```

- [ ] **Step 2: Update AGENTS.md fragment count**

In `AGENTS.md`, change `ALL 13 fragments live in` to `ALL 14 fragments live in`.

- [ ] **Step 3: Verify static checks**

Run from repo root:

```bash
cd playbooks && ansible-playbook site.yml --syntax-check && ansible-lint
```

Expected: both pass, no new warnings.

- [ ] **Step 4: Commit**

```bash
git add playbooks/roles/software/files/zsh/65-mise.zsh AGENTS.md
git commit -m "zsh: activate mise in shell (shims on PATH + hooks)"
```

---

## Deployment (after merge, run by user)

```bash
cd playbooks && ansible-playbook site.yml --tags zsh
```

Open a new zsh window; check `mise bin-paths` resolves and tools symlinked from
`~/.local/share/mise/shims` (e.g. `node` from a project with `.mise.toml`).

## Self-Review

- **Spec coverage:** fragment content identical to spec; shims PATH + guarded activate — Task 1 Step 1. AGENTS.md count — Step 2. Out-of-scope items untouched. ✓
- **Placeholder scan:** no TBD/TODO; all code shown inline. ✓
- **Type consistency:** single task; no cross-task interfaces. ✓

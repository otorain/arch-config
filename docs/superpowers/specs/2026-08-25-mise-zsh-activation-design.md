# Mise zsh Activation — Design

**Date:** 2026-08-25

## Problem

`mise` is installed as a package (`_pacman.yml`), but zsh never activates it:
no fragment in `roles/software/files/zsh/`, no hook in `~/.zshrc`. Verdict:
`mise activate zsh` only installs hooks; it does not put the shims directory
(`~/.local/share/mise/shims`) on PATH.

## Design

Add one fragment, `roles/software/files/zsh/65-mise.zsh`:

```zsh
# mise — dev tool version manager (owned by: zsh)
export PATH="$HOME/.local/share/mise/shims:$PATH"
(( $+commands[mise] )) && eval "$(mise activate zsh)"
```

- Filename `65-mise.zsh` slots between `60-try.zsh` and `70-direnv.zsh`.
- Deployed automatically by the existing `with_fileglob: "zsh/[0-9]*.zsh"`
  task in the zsh app; no task or include changes needed.
- Style matches `60-try.zsh` (guarded init, eval).
- `~/.zshrc` stays untouched (user-owned, deployed once).
- AGENTS.md "13 fragments" count becomes 14.

## Out of scope

Global default tool versions (`mise use -g`), `mise settings`, any changes to
how tools are installed. This only wires the existing installation into zsh.

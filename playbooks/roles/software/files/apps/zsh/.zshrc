# .zshrc — skeleton. Keeps only core env/history and the conf.d loop below;
# tool integrations live in ~/.config/zsh/conf.d/*.zsh,
# deployed per-app by the ansible software role (playbooks/roles/software).

# === Environment variables ===
export EDITOR=nvim
export PATH="$HOME/.local/bin:$PATH"

# === History ===
HISTSIZE="10000"
SAVEHIST="10000"
HISTFILE="$HOME/.zsh_history"
setopt HIST_FCNTL_LOCK HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY
setopt NO_APPEND_HISTORY NO_EXTENDED_HISTORY NO_HIST_EXPIRE_DUPS_FIRST
setopt NO_HIST_FIND_NO_DUPS NO_HIST_IGNORE_ALL_DUPS NO_HIST_SAVE_NO_DUPS

# === App-provided fragments (numbered, sourced in order) ===
for f in ~/.config/zsh/conf.d/*.zsh(N); do
  source "$f"
done

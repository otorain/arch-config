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

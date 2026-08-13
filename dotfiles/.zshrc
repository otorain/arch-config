# .zshrc
# Depends on: zsh, oh-my-zsh (installed by install.sh), zsh-syntax-highlighting,
#             zoxide, fzf, atuin, direnv, yazi, lazygit, try-cli (~/.local/bin)

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
alias lg=lazygit
alias zed=zeditor
alias open=xdg-open

# === Tool integrations ===
eval "$(zoxide init zsh)"

if [[ $options[zle] = on ]]; then
  source <(fzf --zsh)
fi

# catppuccin mocha syntax highlighting colors (install.sh copies to ~/.local/share)
[[ -f ~/.local/share/catppuccin_mocha-zsh-syntax-highlighting.zsh ]] && \
  source ~/.local/share/catppuccin_mocha-zsh-syntax-highlighting.zsh

# try — experimental directory manager (AUR: try)
(( $+commands[try] )) && eval "$(command try init ~/src/tries)"

# yazi: cd into the directory on exit
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  if cwd="$(<"$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# kitty shell integration
if test -n "$KITTY_INSTALLATION_DIR"; then
  export KITTY_SHELL_INTEGRATION="no-rc"
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
fi

eval "$(direnv hook zsh)"

# atuin: only take over Ctrl+R, keep default ↑ behavior
if [[ $options[zle] = on ]]; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

# syntax highlighting must be last
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)

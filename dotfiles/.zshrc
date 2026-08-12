# .zshrc
# 依赖: zsh, oh-my-zsh(install.sh 安装), zsh-syntax-highlighting,
#       zoxide, fzf, atuin, direnv, yazi, lazygit, try-cli(~/.local/bin)

# === 环境变量 ===
export EDITOR=nvim
export DIRENV_LOG_FORMAT="direnv: %s"

# pnpm 全局包目录 + ~/.local/bin（uv tool install 等）
export PATH="$HOME/.local/share/pnpm:$HOME/.local/bin:$PATH"

# === oh-my-zsh ===
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=robbyrussell
plugins=(git sudo history)
source "$ZSH/oh-my-zsh.sh"

# === 历史记录 ===
HISTSIZE="10000"
SAVEHIST="10000"
HISTFILE="$HOME/.zsh_history"
setopt HIST_FCNTL_LOCK HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY
setopt NO_APPEND_HISTORY NO_EXTENDED_HISTORY NO_HIST_EXPIRE_DUPS_FIRST
setopt NO_HIST_FIND_NO_DUPS NO_HIST_IGNORE_ALL_DUPS NO_HIST_SAVE_NO_DUPS

# === 别名 ===
alias lg=lazygit
alias zed=zeditor

# === 工具集成 ===
eval "$(zoxide init zsh)"

if [[ $options[zle] = on ]]; then
  source <(fzf --zsh)
fi

# catppuccin mocha 语法高亮配色（install.sh 复制到 ~/.local/share）
[[ -f ~/.local/share/catppuccin_mocha-zsh-syntax-highlighting.zsh ]] && \
  source ~/.local/share/catppuccin_mocha-zsh-syntax-highlighting.zsh

# try — 实验目录管理（AUR: try）
command -v try &>/dev/null && eval "$(try init ~/src/tries)"

# yazi: 退出时 cd 到所在目录
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  if cwd="$(<"$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# kitty shell 集成
if test -n "$KITTY_INSTALLATION_DIR"; then
  export KITTY_SHELL_INTEGRATION="no-rc"
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
fi

eval "$(direnv hook zsh)"

# atuin: 只接管 Ctrl+R，↑ 保留默认行为
if [[ $options[zle] = on ]]; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

# 语法高亮放最后
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)

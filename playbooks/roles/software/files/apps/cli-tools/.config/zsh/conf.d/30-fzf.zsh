# fzf keybindings/completion, interactive shells only (owned by: cli-tools app)
if [[ $options[zle] = on ]]; then
  source <(fzf --zsh)
fi

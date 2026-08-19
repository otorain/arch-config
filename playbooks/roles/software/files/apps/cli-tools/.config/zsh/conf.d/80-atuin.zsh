# atuin: only take over Ctrl+R, keep default up-arrow behavior (owned by: cli-tools app)
if [[ $options[zle] = on ]]; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

#!/usr/bin/env bash

SCRATCH_DIR="$HOME/.scratchpads"
EDITOR="nvim"
TERMINAL="kitty"
TERMINAL_CLASS="floating-scratchpad"
MENU="rofi"

mkdir -p "$SCRATCH_DIR"

# nullglob so an empty dir yields no entries; ##*/ strips the path (ls|basename breaks on spaces)
shopt -s nullglob
entries=("$SCRATCH_DIR"/*.md)
FILES=""
if ((${#entries[@]})); then
  FILES=$(printf '%s\n' "${entries[@]##*/}")
fi
NEW_ENTRY="[+] 新建"

CHOSEN=$(printf "%s\n%s" "$NEW_ENTRY" "$FILES" | "$MENU" -dmenu -p "选择记事本" -i)

# Exit when the user cancelled the menu
[ -z "$CHOSEN" ] && exit 0

if [ "$CHOSEN" = "$NEW_ENTRY" ]; then
  FILE_PATH="$SCRATCH_DIR/scratch-$(date +%Y%m%d-%H%M%S).md"
else
  FILE_PATH="$SCRATCH_DIR/$CHOSEN"
fi

# --class sets the window class so Hyprland's window rule can float it
exec "$TERMINAL" --class "$TERMINAL_CLASS" -e "$EDITOR" "$FILE_PATH"

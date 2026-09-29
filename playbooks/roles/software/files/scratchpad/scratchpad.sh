#!/usr/bin/env bash

SCRATCH_DIR="$HOME/.scratchpads"
EDITOR="nvim"
TERMINAL="kitty"
TERMINAL_CLASS="floating-scratchpad"
MENU="rofi"

mkdir -p "$SCRATCH_DIR"

# nullglob so an empty dir yields no entries; extglob for the preview strip below
shopt -s nullglob extglob

rel_time() {
  local diff=$(($(date +%s) - $1))
  if   ((diff < 60));       then echo "刚刚"
  elif ((diff < 3600));     then echo "$((diff / 60)) 分钟前"
  elif ((diff < 86400));    then echo "$((diff / 3600)) 小时前"
  elif ((diff < 2592000));  then echo "$((diff / 86400)) 天前"
  elif ((diff < 31536000)); then echo "$((diff / 2592000)) 个月前"
  else echo "$((diff / 31536000)) 年前"
  fi
}

# Pango markup requires escaping &, < and >
# (sed, because bare & in ${var//pat/&} replacement expands to the match
# when bash's patsub_replacement shopt is enabled)
pango_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

# First non-empty line, leading whitespace and markdown heading '#' stripped
preview_of() {
  local line
  line=$(grep -m1 -v '^[[:space:]]*$' "$1" 2>/dev/null || true)
  line=${line##+([[:space:]#])}
  line=${line:0:60}
  [[ -z $line ]] && line="（空）"
  printf '%s' "$line"
}

# Bold, no color: a static span color can't adapt to the selected row's light
# background, while the theme foreground flips automatically.
# Icons are Nerd Font glyphs (CaskaydiaCove NF fallback); two spaces after
# each icon for visual separation.
ICON_PLUS=$'\uf067'    # nf-fa-plus
ICON_FILE=$'\uf0f6'    # nf-fa-file-text-o
ICON_CLOSE=$'\uf00d'   # nf-fa-close
ICON_TRASH=$'\uf014'   # nf-fa-trash-o
NEW_ENTRY="<span weight='bold'>${ICON_PLUS}  新建</span>"

# -format i returns the row index so preview text never maps back to a filename;
# Control+d deletes the selected file (rofi exits 10). kb-remove-char-forward is
# rebound to plain Delete for this instance only: it grabs Control+d by default.
# The menu loops so the list (rebuilt each round) reappears after a delete.
FILE_PATH=""
while [[ -z $FILE_PATH ]]; do
  entries=("$SCRATCH_DIR"/*.md)

  # Sort by mtime, newest first (stat + sort -rn; ls -t breaks on spaces)
  files=()
  mtimes=()
  if ((${#entries[@]})); then
    while IFS=$'\t' read -r mtime path; do
      files+=("$path")
      mtimes+=("$mtime")
    done < <(
      for f in "${entries[@]}"; do
        printf '%s\t%s\n' "$(stat -c %Y "$f")" "$f"
      done | sort -rn
    )
  fi

  rows=("$NEW_ENTRY")
  previews=()
  for i in "${!files[@]}"; do
    raw=$(preview_of "${files[i]}")
    esc=$(pango_escape "$raw")
    rt=$(rel_time "${mtimes[i]}")
    # font_family forces Noto Sans CJK for the time: its half-width digits are
    # proportional (no full-width gap) yet share the CJK baseline with the unit
    rows+=("${ICON_FILE}  ${esc}<span font_family='Noto Sans CJK SC' foreground='#6c7086' size='small'>  ${rt}</span>")
    previews+=("$raw")
  done

  SEL=$(printf '%s\n' "${rows[@]}" | "$MENU" -dmenu -i -p "草稿" \
    -markup-rows -format i \
    -kb-remove-char-forward "Delete" -kb-custom-1 "Control+d")
  rc=$?

  # 1 = cancelled; typed text matching no row comes back as text, not an index -> ignore
  ((rc == 1)) && exit 0
  [[ $SEL =~ ^[0-9]+$ ]] || exit 0
  idx=$SEL

  if ((rc == 10)); then
    if ((idx > 0)); then
      target=${files[idx - 1]}
      confirm=$(printf '%s  取消\n%s  删除\n' "$ICON_CLOSE" "$ICON_TRASH" | "$MENU" -dmenu -i -p "删除「${previews[idx - 1]}」")
      [[ $confirm == "$ICON_TRASH  删除" ]] && rm -- "$target"
    fi
    continue
  fi

  if ((idx == 0)); then
    FILE_PATH="$SCRATCH_DIR/scratch-$(date +%Y%m%d-%H%M%S).md"
  else
    FILE_PATH=${files[idx - 1]}
  fi
done

# --class sets the window class so Hyprland's window rule can float it
exec "$TERMINAL" --class "$TERMINAL_CLASS" -e "$EDITOR" "$FILE_PATH"

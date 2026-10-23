#!/usr/bin/env bash

# F9 → OBS recording toggle. OBS's built-in global hotkeys are X11-only and go
# dead when a native Wayland window has focus, so Hyprland owns F9 and this
# talks to OBS through obs-websocket (obs-cmd) instead.
# The password is read from the live OBS config so no secret lives in the repo.

cfg="$HOME/.config/obs-studio/plugin_config/obs-websocket/config.json"
url="obsws://localhost:4455"

if [[ -f $cfg ]]; then
  auth=$(sed -n 's/.*"auth_required": *\([a-z]*\).*/\1/p' "$cfg")
  pw=$(sed -n 's/.*"server_password": *"\([^"]*\)".*/\1/p' "$cfg")
  [[ $auth == "true" && -n $pw ]] && url="$url/$pw"
fi

obs-cmd --websocket "$url" recording toggle ||
  notify-send "OBS" "录制切换失败：obs-cmd 未安装、OBS 未运行或 websocket 未启用"

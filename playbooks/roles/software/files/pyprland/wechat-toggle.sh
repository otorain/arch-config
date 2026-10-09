#!/bin/sh
# Toggle wechat through pypr only when its window exists; otherwise launch it.
# `pypr toggle` with no matching window raises an on-screen error notification.
if hyprctl clients -j | grep -q '"class": "wechat"'; then
    exec pypr toggle wechat
fi
exec /opt/wechat/wechat

#!/usr/bin/env bash
# Kills whatever wlr-which-key instance is currently showing (root menu
# or a submenu) and starts a brand new one at the root menu. This is what
# lets a submenu action "return home" instead of staying nested or closing
# outright — chain it after a niri command with `;`, e.g.:
#   cmd: "niri msg action maximize-column; /home/.../wlr-which-key-home.sh"

pkill -x wlr-which-key 2>/dev/null

# wait for the old process to actually die before relaunching, otherwise
# the new instance can race with the dying one (flicker / dropped input)
for _ in $(seq 1 20); do
    pgrep -x wlr-which-key >/dev/null || break
    sleep 0.02
done

setsid wlr-which-key >/dev/null 2>&1 &
disown

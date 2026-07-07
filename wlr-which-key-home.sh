#!/usr/bin/env bash
old_pid=$(pgrep -x wlr-which-key)
kill "$old_pid" 2>/dev/null
sleep 0.15
setsid wlr-which-key "$HOME/.config/wlr-which-key/modal.yaml" &
disown

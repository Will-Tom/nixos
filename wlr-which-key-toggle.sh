#!/usr/bin/env bash
# Bound to Mod+F12 (Capslock via keyd). If the modal is open, close it.
# If it's closed, open it fresh at the root menu.

if pgrep -x wlr-which-key >/dev/null; then
    pkill -x wlr-which-key
else
    setsid wlr-which-key >/dev/null 2>&1 &
    disown
fi

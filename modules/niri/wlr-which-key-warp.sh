#!/usr/bin/env bash
# Usage: wlr-which-key-warp.sh <niri action + args...>
# Closes the modal, runs the niri action with no overlay holding focus
# (so warp-mouse-to-focus actually fires), then reopens the modal.

pkill -f 'wlr-which-key modal'
for _ in $(seq 1 20); do
    pgrep -f 'wlr-which-key modal' >/dev/null || break
    sleep 0.02
done

niri msg action "$@"

setsid --fork wlr-which-key modal >/dev/null 2>&1 </dev/null

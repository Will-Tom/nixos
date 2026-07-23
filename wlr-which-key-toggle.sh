#!/usr/bin/env bash
if pkill -f 'wlr-which-key modal'; then
    eww close mode-indicator 2>/dev/null
    exit 0
fi
eww update modetext="normal"
eww open mode-indicator 2>/dev/null
exec wlr-which-key modal

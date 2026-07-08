#!/usr/bin/env bash
# niri fires this on Super+F12 whether the modal is open or not.
# Match by full command line, not process name — that was the bug.
if pkill -f 'wlr-which-key modal'; then
    exit 0
fi
exec wlr-which-key modal

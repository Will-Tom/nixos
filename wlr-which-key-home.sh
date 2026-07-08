#!/usr/bin/env bash
if pgrep -x wlr-which-key >/dev/null; then
    pkill -x wlr-which-key
else
    setsid wlr-which-key -c modal >/dev/null 2>&1 &
    disown
fi

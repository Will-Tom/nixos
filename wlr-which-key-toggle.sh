#!/usr/bin/env bash
if pgrep -x wlr-which-key > /dev/null; then
    pkill -x wlr-which-key
else
    wlr-which-key /home/willisk/.config/wlr-which-key/modal.yaml
fi

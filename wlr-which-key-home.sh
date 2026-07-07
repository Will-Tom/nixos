#!/usr/bin/env bash
pkill -x wlr-which-key 2>/dev/null
sleep 0.1
wlr-which-key /home/willisk/.config/wlr-which-key/modal.yaml

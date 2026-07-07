#!/usr/bin/env bash
trap '' TERM
pkill -x wlr-which-key 2>/dev/null
sleep 0.15
exec wlr-which-key "$HOME/.config/wlr-which-key/modal.yaml"

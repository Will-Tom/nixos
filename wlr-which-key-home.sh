#!/usr/bin/env bash
cfg="$HOME/.config/wlr-which-key/modal.yaml"

# Spawn restart via niri — completely outside wlr-which-key process tree
niri msg action spawn -- sh -c "sleep 0.4; exec wlr-which-key \"$cfg\""

pkill -x wlr-which-key

#!/usr/bin/env bash
cfg="$HOME/.config/wlr-which-key/modal.yaml"

# Detach restart so it survives wlr-which-key (our parent) dying
(
    trap '' HUP
    sleep 0.5
    exec wlr-which-key "$cfg"
) &
disown

pkill -x wlr-which-key

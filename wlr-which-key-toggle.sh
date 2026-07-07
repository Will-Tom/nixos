#!/usr/bin/env bash
if pgrep -x wlr-which-key > /dev/null; then
    AGE=$(ps -o etimes= -p $(pgrep -x wlr-which-key | head -1) 2>/dev/null | tr -d ' ')
    [ "${AGE:-0}" -lt 3 ] && exit 0
    pkill -x wlr-which-key
else
    systemd-run --user --no-block \
      -E WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
      -E XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
      -E HOME="$HOME" \
      -E PATH="$PATH" \
      wlr-which-key "$HOME/.config/wlr-which-key/modal.yaml"
fi

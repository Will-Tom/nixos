#!/usr/bin/env bash
echo "$(date +%T.%N) toggle called, ppid=$PPID parent=$(ps -p $PPID -o comm= 2>/dev/null)" >> /tmp/wlr-which-key-toggle.log
if pgrep -x wlr-which-key > /dev/null; then
    AGE=$(ps -o etimes= -p $(pgrep -x wlr-which-key | head -1) 2>/dev/null | tr -d ' ')
    echo "$(date +%T.%N) running, age=${AGE}s, killing" >> /tmp/wlr-which-key-toggle.log
    pkill -x wlr-which-key
else
    echo "$(date +%T.%N) not running, starting" >> /tmp/wlr-which-key-toggle.log
    systemd-run --user --no-block \
      -E WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
      -E XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
      -E HOME="$HOME" \
      -E PATH="$PATH" \
      wlr-which-key "$HOME/.config/wlr-which-key/modal.yaml"
fi

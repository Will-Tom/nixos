#!/usr/bin/env bash
# /tmp/wlr-which-key-started tracks whether this script launched the current instance.
# If wlr-which-key self-closes (unmatched key), the file is still present when the
# toggle fires again — we use that to skip the reopen.
STARTED=/tmp/wlr-which-key-started

if pgrep -x wlr-which-key > /dev/null; then
    AGE=$(ps -o etimes= -p $(pgrep -x wlr-which-key | head -1) 2>/dev/null | tr -d ' ')
    [ "${AGE:-0}" -lt 3 ] && exit 0
    rm -f "$STARTED"
    pkill -x wlr-which-key
else
    if [ -f "$STARTED" ]; then
        rm -f "$STARTED"
        exit 0
    fi
    touch "$STARTED"
    systemd-run --user --no-block \
      -E WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
      -E XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
      -E HOME="$HOME" \
      -E PATH="$PATH" \
      wlr-which-key "$HOME/.config/wlr-which-key/modal.yaml"
fi

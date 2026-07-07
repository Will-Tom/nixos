#!/usr/bin/env bash
trap  TERM
echo "$(date): home called WD=$WAYLAND_DISPLAY XRD=$XDG_RUNTIME_DIR" >> /tmp/wk-debug.log
pkill -x wlr-which-key 2>/dev/null
echo "pkill done rc=$?" >> /tmp/wk-debug.log
sleep 0.4
echo "after sleep" >> /tmp/wk-debug.log
systemd-run --user --no-block \
  -E WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  -E XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
  -E HOME="$HOME" \
  -E PATH="$PATH" \
  wlr-which-key "$HOME/.config/wlr-which-key/modal.yaml" >> /tmp/wk-debug.log 2>&1
echo "systemd-run done rc=$?" >> /tmp/wk-debug.log

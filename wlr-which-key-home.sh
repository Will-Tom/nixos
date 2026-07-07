#!/usr/bin/env bash
trap '' TERM
pkill -x wlr-which-key 2>/dev/null
sleep 0.3
systemd-run --user --no-block \
  -E WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  -E XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
  -E HOME="$HOME" \
  -E PATH="$PATH" \
  wlr-which-key "$HOME/.config/wlr-which-key/modal.yaml"

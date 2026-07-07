#!/usr/bin/env bash
trap '' TERM
echo "home.sh called with args: $*" >> /tmp/wk-debug.log
[ $# -gt 0 ] && "$@"
echo "after action" >> /tmp/wk-debug.log
pkill -x wlr-which-key 2>/dev/null
sleep 0.3
systemd-run --user --no-block \
  -E WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  -E XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
  -E HOME="$HOME" \
  -E PATH="$PATH" \
  wlr-which-key "$HOME/.config/wlr-which-key/modal.yaml"
echo "after systemd-run" >> /tmp/wk-debug.log

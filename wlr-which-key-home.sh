#!/usr/bin/env bash
cfg="$HOME/.config/wlr-which-key/modal.yaml"

# Register restart as a systemd timer unit — survives this process dying entirely
systemd-run --user --no-block --on-active=0.5 \
  -E WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  -E XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
  -E HOME="$HOME" \
  -E PATH="$PATH" \
  wlr-which-key "$cfg"

pkill -x wlr-which-key

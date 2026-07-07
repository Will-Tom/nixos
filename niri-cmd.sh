#!/usr/bin/env bash
export XDG_RUNTIME_DIR=/run/user/1000
export NIRI_SOCKET=$(ls /run/user/1000/niri.wayland-*.sock 2>/dev/null | head -1)
niri msg action "$@"

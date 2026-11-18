#!/usr/bin/env bash
# Screen zoom around the pointer: steps through the zoom_* cursor-effect
# presets in umbriel/config.toml. umbriel has no native zoom and presets take
# no parameters, so the current level is kept in a runtime file.
# Usage: zoom in|out|reset

levels=(1 1.5 2 3 4 6 8)
state="${XDG_RUNTIME_DIR:-/tmp}/umbriel-zoom"

i=$(cat "$state" 2>/dev/null)
[[ "$i" =~ ^[0-9]+$ ]] && (( i < ${#levels[@]} )) || i=0

case "$1" in
    in)    (( i < ${#levels[@]} - 1 )) && i=$((i + 1)) ;;
    out)   (( i > 0 )) && i=$((i - 1)) ;;
    reset) i=0 ;;
    *)     echo "usage: zoom in|out|reset" >&2; exit 1 ;;
esac
echo "$i" > "$state"

if (( i == 0 )); then
    umbriel msg effect-cursor-reset
    label="Zoom off"
else
    umbriel msg effect-cursor-set "zoom_${levels[i]/./_}"
    label="Zoom ${levels[i]}x"
fi

if [ "$1" = reset ]; then key="MIDDLE"; else key="SCROLL"; fi
~/bin/bar-toast super "$key - $label"

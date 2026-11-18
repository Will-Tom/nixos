#!/usr/bin/env bash
# Shows the MODAL badge + screen border whenever wlr-which-key is open.

WINDOWS="border-top border-bottom border-left border-right mode-indicator"

shown=0
misses=0

while true; do
    if pgrep -f 'wlr-which-key modal' >/dev/null; then
        misses=0
        if [ "$shown" -eq 0 ]; then
            eww open-many $WINDOWS >/dev/null 2>&1
            shown=1
        fi
    else
        misses=$((misses + 1))
        # Debounce: warp.sh briefly kills and relaunches the modal on every
        # h/j/k/l press, so don't hide on a single missed poll.
        if [ "$shown" -eq 1 ] && [ "$misses" -ge 4 ]; then
            eww close $WINDOWS >/dev/null 2>&1
            shown=0
        fi
    fi
    sleep 0.05
done

#!/usr/bin/env bash
shown=0
misses=0
while true; do
    if pgrep -f 'wlr-which-key modal' >/dev/null; then
        misses=0
        if [ "$shown" -eq 0 ]; then
            eww open mode-indicator >/dev/null 2>&1
            shown=1
        fi
    else
        misses=$((misses + 1))
        if [ "$shown" -eq 1 ] && [ "$misses" -ge 3 ]; then
            eww close mode-indicator >/dev/null 2>&1
            shown=0
        fi
    fi
    sleep 0.2
done

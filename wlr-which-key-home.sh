#!/usr/bin/env bash
pkill -f 'wlr-which-key modal'
for _ in $(seq 1 20); do
    pgrep -f 'wlr-which-key modal' >/dev/null || break
    sleep 0.02
done
setsid --fork wlr-which-key modal >/dev/null 2>&1 </dev/null

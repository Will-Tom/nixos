#!/usr/bin/env bash
marker=/tmp/wlrwk-closed
guard_ms=1500

if [ -f "$marker" ]; then
    now=$(date +%s%N)
    last=$(cat "$marker" 2>/dev/null || echo 0)
    if [ $(( (now - last) / 1000000 )) -lt "$guard_ms" ]; then
        exit 0    # the modal just closed itself; this is the leaked re-trigger
    fi
fi

pkill -x wlr-which-key && exit 0
exec wlr-which-key modal

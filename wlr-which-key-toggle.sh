#!/usr/bin/env bash
if pkill -f 'wlr-which-key modal'; then
    exit 0
fi
exec wlr-which-key modal

#!/usr/bin/env bash
# Kill the current instance and relaunch at root, fully detached so it
# survives the parent wlr-which-key that spawned this script dying.
pkill -x wlr-which-key
setsid --fork wlr-which-key modal >/dev/null 2>&1 </dev/null

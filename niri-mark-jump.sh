#!/usr/bin/env bash
mark="$1"
markfile=~/.local/share/niri/marks/"$mark"
[ -f "$markfile" ] || exit 1
id=$(cat "$markfile")
[ -z "$id" ] && exit 1
niri msg action focus-window --id "$id"
wtype -k BackSpace &
disown

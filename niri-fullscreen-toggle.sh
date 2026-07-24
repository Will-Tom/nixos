#!/usr/bin/env bash
id=$(niri msg -j windows | jq -r 'map(select(.is_focused))[0].id // empty')
if [ -n "$id" ]; then
    niri msg action fullscreen-window --id "$id"
else
    niri msg action fullscreen-window
fi

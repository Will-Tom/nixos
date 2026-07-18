#!/usr/bin/env bash
mark="$1"
id=$(niri msg -j focused-window | jq -r '.id // empty')
[ -z "$id" ] && exit 1
mkdir -p ~/.local/share/niri/marks
echo "$id" > ~/.local/share/niri/marks/"$mark"

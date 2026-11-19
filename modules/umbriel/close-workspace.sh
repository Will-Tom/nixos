#!/usr/bin/env bash
# Close every window on the focused workspace (tiled and floating; scratchpad
# windows stay). Session terminals only detach, so their shells keep running.
# Bound to Super+Shift+S and modal S.

ws=$(umbriel workspaces --json | jq -r '.[] | select(.focused) | .id' | head -1)
[ -n "$ws" ] || exit 0

ids=$(umbriel windows --json | jq -r --arg ws "$ws" \
  '.[] | select(.workspace == $ws and (.scratchpad // "") == "") | .id')

for id in $ids; do
  umbriel msg window-close "$id" >/dev/null
done

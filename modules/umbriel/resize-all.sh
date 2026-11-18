#!/usr/bin/env bash
# Set every tiled column on the focused workspace to one width fraction.
# umbriel only resizes the focused column, so focus one window per column,
# resize it, then return focus to where it started.
# Usage: resize-all 0.333|0.5|1.0

fraction=$1
[ -n "$fraction" ] || { echo "usage: resize-all <fraction>" >&2; exit 1; }

focused=$(umbriel focused-window --json)
start=$(jq -r '.id // empty' <<<"$focused")
workspace=$(jq -r '.workspace // empty' <<<"$focused")
[ -n "$workspace" ] || exit 0

# One window per tiled column on that workspace
ids=$(umbriel windows --json | jq -r --arg ws "$workspace" '
    [.[] | select(.workspace == $ws and .floating == false
                  and .minimized == false and .scratchpad == "")]
    | unique_by(.column) | .[].id')

for id in $ids; do
    umbriel msg window-focus "$id"
    umbriel msg window-set-primary-extent "$fraction"
done

[ -n "$start" ] && umbriel msg window-focus "$start"

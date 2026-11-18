#!/usr/bin/env bash
# Float the focused window and fit it to a region drawn with slurp.
# umbriel has no native "float to drawn region": floating size is set as a
# fraction of the output's usable area, and position as an offset inside it.

win=$(umbriel focused-window --json 2>/dev/null)
id=$(jq -r '.id // empty' <<<"$win")
if [ -z "$id" ]; then
    echo "No focused window!"
    exit 1
fi
win_output=$(jq -r '.output' <<<"$win")
is_floating=$(jq -r '.floating' <<<"$win")

# Region in global logical coordinates (bail if cancelled). slurp prints no
# trailing newline, so capture first rather than reading from it directly.
box=$(slurp -d -f '%x %y %w %h') || exit 0
read -r bx by bw bh <<<"$box"
[ -n "$bh" ] || exit 0

# Usable area of the window's output
area=$(umbriel outputs --json | jq -c --arg o "$win_output" '.[] | select(.name == $o) | .usable_area')
ux=$(jq .x <<<"$area"); uy=$(jq .y <<<"$area")
uw=$(jq .width <<<"$area"); uh=$(jq .height <<<"$area")

# The region must lie on the window's own output
cx=$((bx + bw / 2)); cy=$((by + bh / 2))
if [ "$cx" -lt "$ux" ] || [ "$cx" -ge $((ux + uw)) ] || [ "$cy" -lt "$uy" ] || [ "$cy" -ge $((uy + uh)) ]; then
    notify-send "float-to-region" "Draw the region on the window's own monitor ($win_output)" 2>/dev/null
    exit 1
fi

fw=$(awk -v a="$bw" -v b="$uw" 'BEGIN { printf "%.4f", a / b }')
fh=$(awk -v a="$bh" -v b="$uh" 'BEGIN { printf "%.4f", a / b }')

[ "$is_floating" = "true" ] || umbriel msg window-toggle-floating "$id"
umbriel msg window-set-primary-extent "$fw"
umbriel msg window-set-secondary-extent "$fh"
umbriel msg window-move-to top_left $((bx - ux)) $((by - uy)) --window "$id"

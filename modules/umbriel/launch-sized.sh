#!/usr/bin/env bash
# Launch something and open its window at a given width fraction instead of
# the default. umbriel can't tie a window rule to how an app was launched, so
# this waits for the next new tiled window and resizes it.
# Usage: launch-sized <fraction> [command...]   (no command: noctalia launcher)

fraction=$1
shift
[ -n "$fraction" ] || { echo "usage: launch-sized <fraction> [command...]" >&2; exit 1; }

ids() { umbriel windows --json | jq -r '.[] | select(.floating == false) | .id' | sort; }

before=$(ids)
panel_open() { umbriel layers --json | jq -e 'any(.[]; .namespace | test("^noctalia-(attached-)?panel"))' >/dev/null; }

if [ $# -eq 0 ]; then
    # The launcher is a noctalia panel: wait for it to open, then to close.
    noctalia msg panel-open launcher >/dev/null || exit 1
    for _ in $(seq 1 20); do panel_open && break; sleep 0.1; done
    while panel_open; do sleep 0.1; done
else
    "$@" >/dev/null 2>&1 &
fi

# Wait for the app's first tiled window (slow apps, browsers): 15 s after a
# command, 8 s after the launcher closes (nothing appears if it was cancelled).
if [ $# -eq 0 ]; then tries=80; else tries=150; fi
for _ in $(seq 1 "$tries"); do
    new=$(comm -13 <(echo "$before") <(ids) | head -n 1)
    if [ -n "$new" ]; then
        umbriel msg window-focus "$new"
        umbriel msg window-set-primary-extent "$fraction"
        exit 0
    fi
    sleep 0.1
done

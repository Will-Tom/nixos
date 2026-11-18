#!/usr/bin/env bash
# Launch something and open its window at a given width fraction instead of
# the default. umbriel can't tie a window rule to how an app was launched, so
# this waits for the next new tiled window and resizes it.
# Usage: launch-sized <fraction> [command...]   (no command: fuzzel)

fraction=$1
shift
[ -n "$fraction" ] || { echo "usage: launch-sized <fraction> [command...]" >&2; exit 1; }

ids() { umbriel windows --json | jq -r '.[] | select(.floating == false) | .id' | sort; }

before=$(ids)
if [ $# -eq 0 ]; then
    fuzzel || exit 0   # cancelled
else
    "$@" >/dev/null 2>&1 &
fi

# Wait up to 15 s for the app's first tiled window (slow apps, browsers).
for _ in $(seq 1 150); do
    new=$(comm -13 <(echo "$before") <(ids) | head -n 1)
    if [ -n "$new" ]; then
        umbriel msg window-focus "$new"
        umbriel msg window-set-primary-extent "$fraction"
        exit 0
    fi
    sleep 0.1
done

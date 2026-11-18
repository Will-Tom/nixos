#!/usr/bin/env bash
# Launch an app with fuzzel and open its window at half width instead of the
# default full width. umbriel can't tie a window rule to how an app was
# launched, so this waits for the next new tiled window and resizes it.

ids() { umbriel windows --json | jq -r '.[] | select(.floating == false) | .id' | sort; }

before=$(ids)
fuzzel || exit 0   # cancelled

# Wait up to 15 s for the app's first tiled window (slow apps, browsers).
for _ in $(seq 1 150); do
    new=$(comm -13 <(echo "$before") <(ids) | head -n 1)
    if [ -n "$new" ]; then
        umbriel msg window-focus "$new"
        umbriel msg window-set-primary-extent 0.5
        exit 0
    fi
    sleep 0.1
done

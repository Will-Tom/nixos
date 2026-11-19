#!/usr/bin/env bash
# Leave umbriel's modal submap when any mouse button is pressed.
#
# umbriel won't bind a bare mouse button inside a submap (mouse binds need a
# modifier), so this watches the mice directly: while modal is active, one
# evtest per mouse waits for a button press and runs `submap reset`. The
# click itself still reaches the window under the pointer. Read access to
# mouse devices (not keyboards) comes from a udev uaccess rule in umbriel.nix.

readers=()

stop() {
    local pg
    for pg in "${readers[@]}"; do kill -- "-$pg" 2>/dev/null; done
    readers=()
}
trap stop EXIT

start() {
    local dev
    for dev in /dev/input/event*; do
        [ -r "$dev" ] || continue
        udevadm info -q property -n "$dev" | grep -qx 'ID_INPUT_MOUSE=1' || continue
        # Own process group, so stop() also kills its evtest. The reset runs
        # inside the pipeline: right on the press, not when evtest next writes.
        setsid bash -c '
            evtest "$1" | { grep -qm1 -E "EV_KEY.*\(BTN_[A-Z]+\), value 1" &&
                umbriel msg submap reset; }' _ "$dev" &
        readers+=("$!")
    done
}

while read -r line; do
    stop
    case $line in
        *'"data":"modal"'*) start ;;
    esac
done < <(umbriel subscribe submap)

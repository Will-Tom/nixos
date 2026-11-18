#!/usr/bin/env bash
# Show a fading "KEY - action" toast next to the mode badge on the noctalia bar.
# Usage: bar-toast <super|modal|normal> T - Terminal
# The first word picks the toast color (super = blue, modal = red).
mode=$1
shift
noctalia msg plugin willisk/submap-mode:mode all toast "$mode|$*" >/dev/null 2>&1 &

#!/usr/bin/env bash
# Show a fading "KEY - action" toast next to the mode badge on the noctalia bar.
# Usage: bar-toast SUPER + T - Terminal
noctalia msg plugin willisk/submap-mode:mode all toast "$*" >/dev/null 2>&1 &

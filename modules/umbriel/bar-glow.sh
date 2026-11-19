#!/usr/bin/env bash
# Bar glow level, 0 (off) to 10: selects the bar_glow_<n> screen effect on
# every output (presets in config.toml, shaders made by umbriel.nix). The
# level is saved and re-applied at login (autostart "bar-glow apply").
# Usage: bar-glow up|down|apply|<level>

DIR=${XDG_STATE_HOME:-$HOME/.local/state}/bar-glow
DEFAULT=4   # strength 0.12
MAX=10

mkdir -p "$DIR"
level=$(cat "$DIR/level" 2>/dev/null)
[[ $level =~ ^[0-9]+$ ]] || level=$DEFAULT

case $1 in
  up) level=$((level + 1)) ;;
  down) level=$((level - 1)) ;;
  apply) ;;
  [0-9]*) level=$1 ;;
  *) echo "usage: bar-glow up|down|apply|<level 0-$MAX>" >&2; exit 1 ;;
esac
((level < 0)) && level=0
((level > MAX)) && level=$MAX
echo "$level" > "$DIR/level"

# At login the IPC socket may not be up yet
for _ in $(seq 1 50); do umbriel outputs --json >/dev/null 2>&1 && break; sleep 0.1; done

if ((level == 0)); then effect=off; else effect=bar_glow_$level; fi
for out in $(umbriel outputs --json | jq -r '.[] | select(.enabled) | .name'); do
  umbriel msg effect-screen-set "$effect" --output "$out" >/dev/null
done

[ "$1" = apply ] || ~/bin/bar-toast super "SHIFT + PGUP/PGDN - Bar glow $level/$MAX"
exit 0

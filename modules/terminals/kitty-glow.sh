#!/usr/bin/env bash
# Text glow level for kitty, 0 (off) to 10. Writes a pipeline for the level
# and an include file naming it, then makes every kitty reload its config.
# kitty only recompiles shaders when the custom_shaders value changes, so
# each level gets its own pipeline file.
# Usage: kitty-glow up|down|init|<level>

TEMPLATE=${XDG_CONFIG_HOME:-$HOME/.config}/kitty/glow.pipeline.in
DIR=${XDG_STATE_HOME:-$HOME/.local/state}/kitty-glow
DEFAULT=3   # strength 0.06
MAX=10
# strength = level * 0.02

mkdir -p "$DIR"
level=$(cat "$DIR/level" 2>/dev/null)
[[ $level =~ ^[0-9]+$ ]] || level=$DEFAULT

case $1 in
  up) level=$((level + 1)) ;;
  down) level=$((level - 1)) ;;
  init) [ -f "$DIR/glow.conf" ] && exit 0 ;;
  [0-9]*) level=$1 ;;
  *) echo "usage: kitty-glow up|down|init|<level 0-$MAX>" >&2; exit 1 ;;
esac
((level < 0)) && level=0
((level > MAX)) && level=$MAX
echo "$level" > "$DIR/level"

rm -f "$DIR"/glow-*.pipeline
if ((level == 0)); then
  echo "custom_shaders" > "$DIR/glow.conf"
else
  strength=$(printf "0.%03d" $((level * 20)))
  sed "s/@STRENGTH@/$strength/" "$TEMPLATE" > "$DIR/glow-$level.pipeline"
  echo "custom_shaders $DIR/glow-$level.pipeline" > "$DIR/glow.conf"
fi

[ "$1" = init ] || pkill -USR1 -x -u "$UID" kitty
[ "$1" = init ] || ~/bin/bar-toast super "PGUP/PGDN - Text glow $level/$MAX" 2>/dev/null
exit 0

#!/usr/bin/env bash
# Text glow level for kitty, 0 (off) to 10. Writes kitty's shader pipeline
# (glass selection, cursor lens, glow) for the level
# and an include file naming it, then makes every kitty reload its config.
# kitty only recompiles shaders when the custom_shaders value changes, so
# each level and shader version gets its own pipeline file.
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
  init) ;;   # regenerate for the current level (template may have changed)
  [0-9]*) level=$1 ;;
  *) echo "usage: kitty-glow up|down|init|<level 0-$MAX>" >&2; exit 1 ;;
esac
((level < 0)) && level=0
((level > MAX)) && level=$MAX
echo "$level" > "$DIR/level"

rm -f "$DIR"/glow-*.pipeline
# The name carries a hash of the template and shaders: kitty only recompiles
# when the custom_shaders value changes, so an edited shader needs a new name
SHADERS=${XDG_CONFIG_HOME:-$HOME/.config}/kitty/shaders
hash=$(cat "$TEMPLATE" "$SHADERS"/*.slang 2>/dev/null | sha1sum | cut -c1-8)
out="$DIR/glow-$level-$hash.pipeline"
# Level 0 keeps the other shaders (glass selection, cursor lens) and drops
# the glow group
strength=$(printf "0.%03d" $((level * 20)))
if ((level == 0)); then
  sed '/^# GLOW-BEGIN$/,/^# GLOW-END$/d' "$TEMPLATE"
else
  sed "s/@STRENGTH@/$strength/" "$TEMPLATE"
fi > "$out"
echo "custom_shaders $out" > "$DIR/glow.conf"

# Reload every kitty (also on init, so a rebuild reaches open windows)
pkill -USR1 -x -u "$(id -u)" kitty || true
[ "$1" = init ] || ~/bin/bar-toast super "PGUP/PGDN - Text glow $level/$MAX" 2>/dev/null
exit 0

#!/usr/bin/env bash
# Bar glow level, 0 (off) to 10: selects the bar_glow_<n> screen effect
# (presets in config.toml, shaders made by umbriel.nix) on each output, except
# where it would get in the way: an output whose bar is hidden, or that shows
# a fullscreen window, gets no screen effect (which also gives fullscreen apps
# direct scanout back).
# Usage: bar-glow up|down|<level>   change the saved level and apply it
#        bar-glow apply             apply the saved level now
#        bar-glow watch             follow umbriel events and keep it applied
#                                   (bar-glow.service)

DIR=${XDG_STATE_HOME:-$HOME/.local/state}/bar-glow
DEFAULT=4   # strength 0.12
MAX=10

mkdir -p "$DIR"

get_level() {
  local l
  l=$(cat "$DIR/level" 2>/dev/null)
  [[ $l =~ ^[0-9]+$ ]] || l=$DEFAULT
  ((l > MAX)) && l=$MAX
  echo "$l"
}

# "<output> <effect>" per enabled output, from outputs/layers/windows JSON
desired() {
  jq -n -r --argjson o "$1" --argjson l "$2" --argjson w "$3" --arg lvl "$(get_level)" '
    $o[] | select(.enabled) | .name as $n
    | (if $lvl == "0" then "off"
       elif ([$l[] | select(.output == $n and .mapped
                            and (.namespace | test("^noctalia-bar")))] | length) == 0
         then "off"
       elif ([$w[] | select(.output == $n and .fullscreen and .visible)] | length) > 0
         then "off"
       else "bar_glow_\($lvl)" end) as $e
    | "\($n) \($e)"'
}

# Set each output's screen effect where it differs from what's wanted
set_effects() {
  local actual out want
  actual=$(umbriel effects --json | jq -r '.owners[] | select(.type == "output")
    | "\(.name) \(if .slots.screen.suppressed or .slots.screen.name == "" then "off"
                 else .slots.screen.name end)"')
  while read -r out want; do
    [ -n "$out" ] || continue
    grep -qxF "$out $want" <<<"$actual" && continue
    umbriel msg effect-screen-set "$want" --output "$out" >/dev/null
  done <<<"$1"
}

apply_now() {
  set_effects "$(desired "$(umbriel outputs --json)" "$(umbriel layers --json)" "$(umbriel windows --json)")"
}

wait_ipc() {
  for _ in $(seq 1 100); do umbriel outputs --json >/dev/null 2>&1 && return 0; sleep 0.1; done
  return 1
}

watch() {
  wait_ipc || exit 1
  local outputs='[]' layers='[]' windows='[]' line ev last= now
  # Each event is a full snapshot of its family; keep the newest of each and
  # only touch umbriel when the wanted effects change.
  umbriel subscribe outputs,layers,windows | while read -r line; do
    ev=$(jq -r '.event' <<<"$line")
    case $ev in
      outputs) outputs=$(jq -c '.data' <<<"$line") ;;
      layers) layers=$(jq -c '.data' <<<"$line") ;;
      windows) windows=$(jq -c '.data' <<<"$line") ;;
      *) continue ;;
    esac
    # Skip bursts (drags send a snapshot every 16 ms): only the newest matters
    read -r -t 0 && continue
    now=$(desired "$outputs" "$layers" "$windows")
    [ "$now" = "$last" ] && continue
    last=$now
    set_effects "$now"
  done
}

case $1 in
  watch) watch; exit ;;
  apply) wait_ipc && apply_now; exit 0 ;;
  up) level=$(($(get_level) + 1)) ;;
  down) level=$(($(get_level) - 1)) ;;
  [0-9]*) level=$1 ;;
  *) echo "usage: bar-glow up|down|apply|watch|<level 0-$MAX>" >&2; exit 1 ;;
esac
((level < 0)) && level=0
((level > MAX)) && level=$MAX
echo "$level" > "$DIR/level"
apply_now
~/bin/bar-toast super "SHIFT + PGUP/PGDN - Bar glow $level/$MAX"
exit 0

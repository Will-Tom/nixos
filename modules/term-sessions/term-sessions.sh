#!/usr/bin/env bash
# Persistent terminal sessions: kitty windows on shpool shells, grouped into
# named sessions, saved every few minutes and restored after a reboot.
#
#   shell    one shpool shell (id like t-4f2a9c), shown in one kitty window
#            whose Wayland tag (kitty --name) is term:<id>
#   session  a named group of shells; bookkeeping only, in $STATE/state.json
#
# Installed as ~/bin/term-sessions, ~/bin/term (= new) and ~/bin/term-attach
# (= attach); the name it's called by picks the default command.
#
#   term [--session S] [--fraction F] [--dir D]   open a new terminal
#   term-attach <id>        run inside kitty: attach, or recreate after reboot
#   term-sessions detach    close the focused window, keep its shell running
#   term-sessions end       stop persisting the focused session (D)
#   term-sessions move S    put the focused shell in session S (n)
#   term-sessions merge S   move the focused session's shells into S (N)
#   term-sessions rename S  rename the focused session (r)
#   term-sessions clone S   new session S with a fresh shell per shell (c)
#   term-sessions open S    reopen session S's windows (s)
#   term-sessions list      sessions as JSON (for the launcher)
#   term-sessions prompt V  remember the focused shell, open the launcher on /ts V
#   term-sessions save      snapshot cwd, scrollback and placement (timer)
#   term-sessions restore   reopen every shell that was open (login)

set -uo pipefail
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/term-sessions
DB=$STATE/state.json
SCROLL=$STATE/scroll
RUN=${XDG_RUNTIME_DIR:-/run/user/$UID}
TARGET=$RUN/term-sessions.target      # shell the launcher prompt acts on
RESTORED=$RUN/term-sessions.restored  # save is a no-op until restore ran
SCROLL_LINES=5000
mkdir -p "$SCROLL"
[ -s "$DB" ] || echo '{"shells":{}}' > "$DB"

# ---- state helpers --------------------------------------------------------

# Apply a jq filter to the state file under a lock.
db_update() {
  (
    flock 9
    tmp=$(mktemp "$DB.XXXX")
    if jq "$@" "$DB" > "$tmp"; then mv "$tmp" "$DB"; else rm -f "$tmp"; exit 1; fi
  ) 9>"$DB.lock"
}
db() { jq "$@" "$DB"; }

shpool_ids() { shpool list --json 2>/dev/null | jq -r '.sessions[]? | .name'; }
shpool_attached() { shpool list --json 2>/dev/null | jq -r '.sessions[]? | select((.status|tostring|ascii_downcase) == "attached") | .name'; }

# id of a shell from a window's xdg_tag
focused_id() {
  umbriel focused-window --json 2>/dev/null | jq -r '.xdg_tag // "" | select(startswith("term:")) | ltrimstr("term:")'
}
# The shell to act on: the one recorded by `prompt`, else the focused one.
target_id() {
  local id=""
  [ -s "$TARGET" ] && id=$(cat "$TARGET")
  [ -n "$id" ] || id=$(focused_id)
  echo "$id"
}
session_of() { db -r --arg id "$1" '.shells[$id].session // empty'; }

toast() { ~/bin/bar-toast modal "$1" 2>/dev/null; }

# cwd of a shpool shell: the oldest non-shpool process carrying SHPOOL_SESSION_NAME=<id>
# is the shell itself (anything it runs inherits the variable).
shell_cwd() {
  local id=$1 p
  for p in $(pgrep -u "$UID" | sort -n); do
    case $(readlink "/proc/$p/exe" 2>/dev/null) in */shpool) continue ;; esac  # shpool's own helpers
    if tr "\\0" "\\n" 2>/dev/null < "/proc/$p/environ" | grep -qx "SHPOOL_SESSION_NAME=$id"; then
      readlink "/proc/$p/cwd" 2>/dev/null && return
    fi
  done
}

window_of() { umbriel windows --json | jq -r --arg t "term:$1" '.[] | select(.xdg_tag == $t) | .id' | head -1; }

# Wait for the window of a shell to map; prints its umbriel id.
wait_window() {
  local id=$1 w
  for _ in $(seq 1 100); do
    w=$(window_of "$id")
    [ -n "$w" ] && { echo "$w"; return 0; }
    sleep 0.1
  done
  return 1
}

# Start a kitty window for a shell (detached from this script).
spawn_window() {
  # Remote control only on session windows: save reads their scrollback
  setsid -f kitty -o allow_remote_control=socket-only -o "listen_on=unix:$RUN/kitty-{kitty_pid}" \
    --name "term:$1" -e "${TERM_ATTACH:-$HOME/bin/term-attach}" "$1" >/dev/null 2>&1
}

# Put a mapped window on a workspace/output and set its width.
place_window() {
  local w=$1 ws=$2 out=$3 extent=$4
  umbriel msg window-focus "$w" >/dev/null
  if [ -n "$ws" ] && [ "$ws" != null ]; then
    umbriel msg window-move-to-workspace-silent "${ws#*:}" --output "$out" >/dev/null
    umbriel msg window-focus "$w" >/dev/null
  fi
  if [ -n "$extent" ] && [ "$extent" != null ]; then
    umbriel msg window-set-primary-extent "$extent" >/dev/null
  fi
}

new_id() { echo "t-$(head -c3 /dev/urandom | od -An -tx1 | tr -d ' \n')"; }

# ---- commands ---------------------------------------------------------------

cmd_new() {
  local session="" fraction="" dir="$HOME" id w focus
  while [ $# -gt 0 ]; do
    case $1 in
      --session) session=$2; shift 2 ;;
      --fraction) fraction=$2; shift 2 ;;
      --dir) dir=$2; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ -z "$session" ]; then
    focus=$(focused_id)
    [ -n "$focus" ] && session=$(session_of "$focus")
    [ -n "$session" ] || session=main
  fi
  id=$(new_id)
  db_update --arg id "$id" --arg s "$session" --arg d "$dir" \
    '.shells[$id] = {session: $s, cwd: $d, open: true}'
  spawn_window "$id"
  if [ -n "$fraction" ] && w=$(wait_window "$id"); then
    umbriel msg window-focus "$w" >/dev/null
    umbriel msg window-set-primary-extent "$fraction" >/dev/null
  fi
}

cmd_attach() {
  local id=$1 cwd file
  if shpool_ids | grep -qx "$id"; then
    shpool attach -f "$id"
  else
    # Not running (new shell, or recreated after a reboot)
    cwd=$(db -r --arg id "$id" '.shells[$id].cwd // empty')
    [ -d "$cwd" ] || cwd=$HOME
    file=$SCROLL/$id.ansi
    if [ -s "$file" ]; then
      cat "$file"
      printf '\n\033[2m── restored from %s ──\033[0m\n' "$(date -r "$file" '+%Y-%m-%d %H:%M')"
    fi
    shpool attach -d "$cwd" "$id"
  fi
  # Shell exited (exit / ctrl-d) or session ended (D): forget it.
  # Detached (d, or window closed): keep it, now in the background.
  if ! shpool_ids | grep -qx "$id"; then
    db_update --arg id "$id" 'del(.shells[$id])'
    rm -f "$SCROLL/$id.ansi"
  elif [ -z "$(db -r --arg id "$id" '.shells[$id] // empty')" ]; then
    shpool kill "$id" >/dev/null 2>&1
  else
    db_update --arg id "$id" '.shells[$id].open = false'
  fi
}

cmd_detach() {
  local id; id=$(focused_id)
  [ -n "$id" ] || { toast "d - Not a session terminal"; return 1; }
  shpool detach "$id" >/dev/null
}

cmd_end() {
  local id s
  id=$(focused_id); s=$(session_of "$id")
  [ -n "$s" ] || { toast "D - Not a session terminal"; return 1; }
  # Detached shells of the session die now; open windows stay as plain
  # terminals (term-attach kills their shell when they close).
  for sid in $(db -r --arg s "$s" '.shells | to_entries[] | select(.value.session == $s and .value.open != true) | .key'); do
    shpool kill "$sid" >/dev/null 2>&1
    rm -f "$SCROLL/$sid.ansi"
  done
  db_update --arg s "$s" '.shells |= with_entries(select(.value.session != $s))'
  toast "D - Ended session $s"
}

cmd_move() {
  local id; id=$(target_id)
  [ -n "$id" ] || return 1
  db_update --arg id "$id" --arg s "$1" '.shells[$id].session = $s'
  toast "n - Moved to $1"
}

cmd_merge() {   # also rename: every shell of the target's session goes to $1
  local id s; id=$(target_id); s=$(session_of "$id")
  [ -n "$s" ] || return 1
  db_update --arg from "$s" --arg to "$1" \
    '.shells |= map_values(if .session == $from then .session = $to else . end)'
  toast "${2:-N} - $s → $1"
}

cmd_clone() {
  local id s new w
  id=$(target_id); s=$(session_of "$id")
  [ -n "$s" ] || return 1
  cmd_save_quiet
  db -c --arg s "$s" '[.shells | to_entries[] | select(.value.session == $s)] | sort_by(.value.workspace // "", .value.column // 0)[] | .value' |
  while read -r sh; do
    new=$(new_id)
    db_update --arg id "$new" --arg to "$1" --argjson sh "$sh" \
      '.shells[$id] = {session: $to, cwd: $sh.cwd, open: true}'
    spawn_window "$new"
    if w=$(wait_window "$new"); then
      place_window "$w" "$(jq -r '.workspace // empty' <<<"$sh")" "$(jq -r '.output // empty' <<<"$sh")" "$(jq -r '.extent // empty' <<<"$sh")"
    fi
  done
  toast "c - Cloned $s as $1"
}

cmd_open() {
  local s=$1 w sid
  db -c --arg s "$s" '[.shells | to_entries[] | select(.value.session == $s)] | sort_by(.value.workspace // "", .value.column // 0)[]' |
  while read -r e; do
    sid=$(jq -r .key <<<"$e")
    w=$(window_of "$sid")
    if [ -z "$w" ]; then
      db_update --arg id "$sid" '.shells[$id].open = true'
      spawn_window "$sid"
      w=$(wait_window "$sid") || continue
      place_window "$w" "$(jq -r '.value.workspace // empty' <<<"$e")" "$(jq -r '.value.output // empty' <<<"$e")" "$(jq -r '.value.extent // empty' <<<"$e")"
    fi
    echo "$w" > "$RUN/term-sessions.last"
  done
  [ -s "$RUN/term-sessions.last" ] && umbriel msg window-focus "$(cat "$RUN/term-sessions.last")" >/dev/null
  rm -f "$RUN/term-sessions.last"
}

cmd_list() {
  local focus; focus=$(session_of "$(target_id)")
  db --arg f "$focus" '[.shells | to_entries | group_by(.value.session)[] |
      {name: .[0].value.session, shells: length,
       open: (map(select(.value.open == true)) | length), focused: (.[0].value.session == $f)}]'
}

cmd_prompt() {
  local id; id=$(focused_id)
  if [ -z "$id" ] && [ "$1" != open ]; then toast "Not a session terminal"; return 1; fi
  echo "$id" > "$TARGET"
  noctalia msg panel-open launcher "/ts $1 " >/dev/null
}

cmd_save_quiet() { cmd_save >/dev/null 2>&1; }

cmd_save() {
  [ -e "$RESTORED" ] || return 0
  # While logging out windows close one by one; saving then would record them
  # as closed and they wouldn't come back. Keep the last snapshot instead.
  [ "${TERM_SESSIONS_FORCE:-}" = 1 ] || systemctl --user -q is-active graphical-session.target || return 0
  local wins outs live attached
  wins=$(umbriel windows --json 2>/dev/null) || return 0
  outs=$(umbriel outputs --json 2>/dev/null)
  live=$(shpool_ids)
  attached=$(shpool_attached)

  # Placement of every open session window
  local place
  place=$(jq -c --argjson outs "${outs:-[]}" '
    [.[] | select(.xdg_tag // "" | startswith("term:")) |
      . as $w | ($outs[] | select(.name == $w.output) | .usable_area.width) as $uw |
      {key: (.xdg_tag | ltrimstr("term:")),
       value: {workspace, output, column, pid,
               extent: (if $uw and $uw > 0 then ((.w / $uw * 1000 | round) / 1000) else null end)}}
    ] | from_entries' <<<"$wins")

  local cwds="{}" id cwd pid sock
  for id in $(db -r '.shells | keys[]'); do
    if grep -qx "$id" <<<"$live"; then
      cwd=$(shell_cwd "$id")
      [ -n "$cwd" ] && cwds=$(jq -c --arg id "$id" --arg c "$cwd" '.[$id] = $c' <<<"$cwds")
    fi
    pid=$(jq -r --arg id "$id" '.[$id].pid // empty' <<<"$place")
    sock=$RUN/kitty-$pid
    if [ -n "$pid" ] && [ -S "$sock" ]; then
      kitten @ --to "unix:$sock" get-text --match "cmdline:$id" --extent all --ansi 2>/dev/null \
        | tail -n "$SCROLL_LINES" > "$SCROLL/$id.ansi.tmp" && mv "$SCROLL/$id.ansi.tmp" "$SCROLL/$id.ansi"
    fi
  done

  db_update --argjson place "$place" --argjson cwds "$cwds" '
    .shells |= with_entries(
      .key as $id |
      .value.open = ($place[$id] != null) |
      (if $place[$id] then .value += ($place[$id] | del(.pid)) else . end) |
      (if $cwds[$id] then .value.cwd = $cwds[$id] else . end))
    | .saved = (now | localtime | strftime("%Y-%m-%d %H:%M"))'

  # Shells no longer in any session (ended with D) die once detached
  local known; known=$(db -r '.shells | keys[]')
  for id in $live; do
    case $id in t-*) ;; *) continue ;; esac
    grep -qx "$id" <<<"$known" && continue
    grep -qx "$id" <<<"$attached" || shpool kill "$id" >/dev/null 2>&1
  done
  # Drop scrollback files of forgotten shells
  for f in "$SCROLL"/*.ansi; do
    [ -e "$f" ] || continue
    id=$(basename "$f" .ansi)
    grep -qx "$id" <<<"$known" || rm -f "$f"
  done
}

cmd_restore() {
  local e sid w
  db -c '[.shells | to_entries[] | select(.value.open == true)] | sort_by(.value.output // "", .value.workspace // "", .value.column // 0)[]' |
  while read -r e; do
    sid=$(jq -r .key <<<"$e")
    [ -n "$(window_of "$sid")" ] && continue
    spawn_window "$sid"
    w=$(wait_window "$sid") || continue
    place_window "$w" "$(jq -r '.value.workspace // empty' <<<"$e")" "$(jq -r '.value.output // empty' <<<"$e")" "$(jq -r '.value.extent // empty' <<<"$e")"
  done
  touch "$RESTORED"
}

# ---- dispatch ---------------------------------------------------------------

case $(basename "$0") in
  term) cmd_new "$@"; exit ;;
  term-attach) cmd_attach "$@"; exit ;;
esac

cmd=${1:-}; shift || true
case $cmd in
  new) cmd_new "$@" ;;
  attach) cmd_attach "$@" ;;
  detach) cmd_detach ;;
  end) cmd_end ;;
  move) cmd_move "$1" ;;
  merge) cmd_merge "$1" N ;;
  rename) cmd_merge "$1" r ;;
  clone) cmd_clone "$1" ;;
  open) cmd_open "$1" ;;
  list) cmd_list ;;
  prompt) cmd_prompt "$1" ;;
  save) cmd_save ;;
  restore) cmd_restore ;;
  *) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1 ;;
esac

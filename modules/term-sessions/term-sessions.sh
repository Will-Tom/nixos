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
#   term [--fraction F]     open a plain terminal (no session, not kept)
#   term --session S [--fraction F] [--dir D]   new terminal in session S
#   term-attach <id>        run inside kitty: attach, or recreate after reboot
#   term-sessions detach    close the focused window, keep its shell running (d)
#   term-sessions end       stop persisting the focused session (D)
#   term-sessions close-all close the focused session's windows, shells keep running (s)
#   term-sessions kill-all  close them and kill the session's shells (S)
#   term-sessions focus     session, cwd and command of the focused terminal (bar)
#   term-sessions move S    put the focused shell in session S (m)
#   term-sessions merge S   move the focused session's shells into S (M)
#   term-sessions rename S  rename the focused session (r)
#   term-sessions clone S   copy the focused session's shells into S, new or
#                           existing (c new name, C existing session)
#   term-sessions open S    reopen session S's windows (/)
#   term-sessions list      sessions as JSON (for the launcher)
#   term-sessions prompt V  remember the focused shell, open the launcher on
#                           /ts V, return to SESSIONS mode when it closes
#   term-sessions se ...    the same actions from a shell (fish `se`), see se_help
#   term-sessions save      snapshot cwd, scrollback and placement (timer)
#   term-sessions restore   reopen every shell that was open (login)
#
# "Focused" means the shell you're typing in when run from a session shell
# ($SHPOOL_SESSION_NAME), else the focused umbriel window.

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
# The shell this command acts on: the one it's typed in, else the focused window
cur_id() {
  if [ -n "${SHPOOL_SESSION_NAME:-}" ]; then echo "$SHPOOL_SESSION_NAME"; else focused_id; fi
}
# Same, but launcher actions use the shell recorded by `prompt`
target_id() {
  local id=""
  [ -n "${SHPOOL_SESSION_NAME:-}" ] && { echo "$SHPOOL_SESSION_NAME"; return; }
  [ -s "$TARGET" ] && id=$(cat "$TARGET")
  [ -n "$id" ] || id=$(focused_id)
  echo "$id"
}
session_of() { db -r --arg id "$1" '.shells[$id].session // empty'; }

# Open windows on this desktop, or work in the current terminal (ssh)?
# A session shell is local when it's shown in a kitty window here.
gui() {
  [ "${TERM_SESSIONS_TTY:-}" = 1 ] && return 1
  if [ -n "${SHPOOL_SESSION_NAME:-}" ]; then
    [ -n "$(window_of "$SHPOOL_SESSION_NAME" 2>/dev/null)" ]
  else
    [ -z "${SSH_CONNECTION:-}" ] && umbriel outputs >/dev/null 2>&1
  fi
}

# Bar toast for keybinds; also printed when run from a terminal
toast() {
  ~/bin/bar-toast modal "$1" 2>/dev/null
  [ -t 2 ] && echo "$1" >&2
  return 0
}

# pid of a shpool shell. Shells are direct children of the shpool daemon and
# carry SHPOOL_SESSION_NAME=<id>; fall back to scanning all of our processes.
shell_pid() {
  local id=$1 daemon p
  daemon=$(systemctl --user show -p MainPID --value shpool 2>/dev/null)
  if [ -n "$daemon" ] && [ "$daemon" != 0 ]; then
    for p in $(pgrep -P "$daemon"); do
      tr "\\0" "\\n" 2>/dev/null < "/proc/$p/environ" | grep -qx "SHPOOL_SESSION_NAME=$id" && { echo "$p"; return; }
    done
  fi
  for p in $(pgrep -u "$UID" | sort -n); do
    case $(readlink "/proc/$p/exe" 2>/dev/null) in */shpool) continue ;; esac  # shpool's own helpers
    tr "\\0" "\\n" 2>/dev/null < "/proc/$p/environ" | grep -qx "SHPOOL_SESSION_NAME=$id" && { echo "$p"; return; }
  done
}
shell_cwd() { local p; p=$(shell_pid "$1") && [ -n "$p" ] && readlink "/proc/$p/cwd" 2>/dev/null; }

# Command running in the foreground of a shell (empty at the prompt)
shell_fg() {
  local p=$1 tpgid
  tpgid=$(awk '{ sub(/^.*\) /, ""); print $6 }' "/proc/$p/stat" 2>/dev/null)
  [ -n "$tpgid" ] && [ "$tpgid" != "$p" ] && [ "$tpgid" -gt 0 ] || return 0
  # "/nix/store/…-helix/bin/hx file" -> "hx file"
  tr '\0' ' ' < "/proc/$tpgid/cmdline" 2>/dev/null | sed -e 's/ $//' -e 's|^[^ ]*/||'
}

window_tagged() { umbriel windows --json | jq -r --arg t "$1" '.[] | select(.xdg_tag == $t) | .id' | head -1; }
window_of() { window_tagged "term:$1"; }

# Wait for the window of a shell (or, with $2 = tag, any tagged window) to
# map; prints its umbriel id.
wait_window() {
  local id=$1 tag=${2:-term:$1} w
  for _ in $(seq 1 100); do
    w=$(window_tagged "$tag")
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

# A plain terminal: kitty with the login shell, in no session and not saved
# (Super+T, modal t)
cmd_plain() {
  local fraction=$1 tag w
  if ! gui; then echo "Not on the desktop: use se t to open a session shell" >&2; return 1; fi
  tag="plain:$(head -c3 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  setsid -f kitty --name "$tag" >/dev/null 2>&1
  if [ -n "$fraction" ] && w=$(wait_window "" "$tag"); then
    umbriel msg window-focus "$w" >/dev/null
    umbriel msg window-set-primary-extent "$fraction" >/dev/null
  fi
}

# New terminal; in session --session S, else a plain one (never a default
# session)
cmd_new() {
  local session="" fraction="" dir="$HOME" id w
  while [ $# -gt 0 ]; do
    case $1 in
      --session) session=$2; shift 2 ;;
      --fraction) fraction=$2; shift 2 ;;
      --dir) dir=$2; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ -z "$session" ]; then cmd_plain "$fraction"; return; fi
  id=$(new_id)
  db_update --arg id "$id" --arg s "$session" --arg d "$dir" \
    '.shells[$id] = {session: $s, cwd: $d, open: true}'
  if ! gui; then
    # Over ssh: the new shell takes over this terminal until detached
    echo "New shell $id in session $session (detach with: se d)" >&2
    cmd_attach "$id"
    return
  fi
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
  local id; id=$(cur_id)
  [ -n "$id" ] || { toast "d - Not a session terminal"; return 1; }
  shpool detach "$id" >/dev/null
}

cmd_end() {
  local id s
  id=$(cur_id); s=$(session_of "$id")
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

# s: close every window of the focused session; the shells keep running
cmd_close_all() {
  local id s sid
  id=$(cur_id); s=$(session_of "$id")
  [ -n "$s" ] || { toast "s - Not a session terminal"; return 1; }
  toast "s - Closed $s (still running)"
  for sid in $(db -r --arg s "$s" '.shells | to_entries[] | select(.value.session == $s and .value.open == true) | .key'); do
    shpool detach "$sid" >/dev/null 2>&1
  done
}

# S: close every window of the focused session and kill all its shells
cmd_kill_all() {
  local id s sid ids
  id=$(cur_id); s=$(session_of "$id")
  [ -n "$s" ] || { toast "S - Not a session terminal"; return 1; }
  ids=$(db -r --arg s "$s" '.shells | to_entries[] | select(.value.session == $s) | .key')
  db_update --arg s "$s" '.shells |= with_entries(select(.value.session != $s))'
  toast "S - Killed session $s"
  for sid in $ids; do
    shpool kill "$sid" >/dev/null 2>&1
    rm -f "$SCROLL/$sid.ansi"
  done
}

# For the bar widget: session, cwd and foreground command of the focused terminal
cmd_focus() {
  local id s p cwd fg
  id=$(focused_id)
  [ -n "$id" ] || { echo '{}'; return; }
  s=$(session_of "$id")
  p=$(shell_pid "$id")
  if [ -n "$p" ]; then
    cwd=$(readlink "/proc/$p/cwd" 2>/dev/null)
    fg=$(shell_fg "$p")
  fi
  jq -nc --arg s "$s" --arg c "${cwd:-}" --arg f "${fg:-}" --arg h "$HOME" \
    '{session: $s, cwd: (if $c | startswith($h) then "~" + ($c | ltrimstr($h)) else $c end), cmd: $f}'
}

cmd_move() {
  local id; id=$(target_id)
  [ -n "$id" ] || return 1
  db_update --arg id "$id" --arg s "$1" '.shells[$id].session = $s'
  toast "m - Moved to $1"
}

cmd_merge() {   # also rename: every shell of the target's session goes to $1
  local id s; id=$(target_id); s=$(session_of "$id")
  [ -n "$s" ] || return 1
  db_update --arg from "$s" --arg to "$1" \
    '.shells |= map_values(if .session == $from then .session = $to else . end)'
  toast "${2:-N} - $s → $1"
}

cmd_clone() {   # $2: key for the toast (c new session, C existing session)
  local id s new w cwd win=1
  id=$(target_id); s=$(session_of "$id")
  [ -n "$s" ] || return 1
  gui || win=0
  TERM_SESSIONS_FORCE=1 cmd_save_quiet   # fresh cwds
  db -c --arg s "$s" '[.shells | to_entries[] | select(.value.session == $s)] | sort_by(.value.workspace // "", .value.column // 0)[] | .value' |
  while read -r sh; do
    new=$(new_id)
    cwd=$(jq -r '.cwd // empty' <<<"$sh"); [ -d "$cwd" ] || cwd=$HOME
    if [ $win = 1 ]; then
      db_update --arg id "$new" --arg to "$1" --arg c "$cwd" '.shells[$id] = {session: $to, cwd: $c, open: true}'
      spawn_window "$new"
      if w=$(wait_window "$new"); then
        place_window "$w" "$(jq -r '.workspace // empty' <<<"$sh")" "$(jq -r '.output // empty' <<<"$sh")" "$(jq -r '.extent // empty' <<<"$sh")"
      fi
    else
      # Over ssh: start the shells in the background; reopen them with se /
      db_update --arg id "$new" --arg to "$1" --arg c "$cwd" '.shells[$id] = {session: $to, cwd: $c, open: false}'
      shpool attach -b -d "$cwd" "$new" >/dev/null 2>&1
    fi
  done
  toast "${2:-c} - Cloned $s into $1"
}

# Over ssh: pick one of the session's shells and attach it in this terminal
open_here() {
  local s=$1 ids n i=1 choice
  mapfile -t ids < <(db -r --arg s "$s" '.shells | to_entries[] | select(.value.session == $s) | .key')
  n=${#ids[@]}
  [ "$n" -gt 0 ] || { echo "Session $s has no shells" >&2; return 1; }
  if [ "$n" -gt 1 ]; then
    for id in "${ids[@]}"; do
      printf '  %d) %s  %s%s\n' "$i" "$id" "$(db -r --arg id "$id" '.shells[$id].cwd // ""')" \
        "$(shpool_attached | grep -qx "$id" && echo '  (attached elsewhere)')" > /dev/tty
      i=$((i + 1))
    done
    read -r -p "Shell [1-$n]: " choice < /dev/tty || return 1
    [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$n" ] || return 1
  else
    choice=1
  fi
  cmd_attach "${ids[$((choice - 1))]}"
}

cmd_open() {
  local s=$1 w sid
  gui || { open_here "$s"; return; }
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

launcher_open() { umbriel layers --json 2>/dev/null | jq -e 'any(.[]; .namespace | test("^noctalia-(attached-)?panel"))' >/dev/null; }

# The keybind leaves modal (so typing in the launcher doesn't hit SESSIONS
# keys); once the launcher closes, go back into SESSIONS mode.
# SESSIONS t/T: new terminal in the focused terminal's session; when the
# focused window isn't a session terminal, ask for the session in the
# launcher first. $1: width fraction or empty
cmd_session_new() {
  local id s=""
  id=$(focused_id)
  [ -n "$id" ] && s=$(session_of "$id")
  if [ -n "$s" ]; then
    cmd_new --session "$s" ${1:+--fraction "$1"}
  else
    # leave SESSIONS and modal so typing the name doesn't hit their keys
    umbriel msg submap reset >/dev/null; umbriel msg submap reset >/dev/null
    cmd_prompt "$( [ -n "${1:-}" ] && echo new3 || echo new )"
  fi
}

cmd_prompt() {
  local id; id=$(focused_id)
  if [ -n "$id" ] || [ "$1" = open ] || [ "$1" = new ] || [ "$1" = new3 ]; then
    echo "$id" > "$TARGET"
    noctalia msg panel-open launcher "/ts $1 " >/dev/null
    for _ in $(seq 1 20); do launcher_open && break; sleep 0.1; done
    while launcher_open; do sleep 0.1; done
  else
    toast "Not a session terminal"
  fi
  umbriel msg submap modal >/dev/null
  umbriel msg submap sessions >/dev/null
}

# ---- se: the SESSIONS actions from a shell ---------------------------------

se_help() {
  cat >&2 <<'EOF'
se t        new terminal in this session      se T   same, at 1/3 width
se d        detach this shell                  se D   end this session (windows stay)
se s        close all of this session's windows  se S   close them and kill the session
se m [S]    move this shell to session S       se M [S]  merge this session into S
se c [S]    clone this session as new S        se C [S]  clone into existing S
se / [S]    open session S (over ssh: attach one of its shells here)
se r [S]    rename this session                se ls  list sessions
Without S you're prompted. Over ssh, new shells take over this terminal.
EOF
}

# Prompt for a session: number from the list, or a name.
#   $1 prompt  $2 allow new names (1/0)  $3 session to leave out of the list
ask_session() {
  local prompt=$1 allow_new=$2 skip=${3:-} names n i=1 ans
  mapfile -t names < <(db -r --arg k "$skip" '[.shells[].session] | unique | map(select(. != $k))[]')
  for s in "${names[@]}"; do
    printf '  %d) %s  (%s)\n' "$i" "$s" "$(db -r --arg s "$s" '[.shells[] | select(.session == $s)] | "\(length) shells, \(map(select(.open == true)) | length) open"')" > /dev/tty
    i=$((i + 1))
  done
  n=${#names[@]}
  read -r -p "$prompt" ans < /dev/tty || return 1
  [ -n "$ans" ] || return 1
  if [[ "$ans" =~ ^[0-9]+$ ]] && [ "$ans" -ge 1 ] && [ "$ans" -le "$n" ]; then
    echo "${names[$((ans - 1))]}"
  elif printf '%s\n' "${names[@]}" | grep -qx -- "$ans" || [ "$allow_new" = 1 ]; then
    echo "$ans"
  else
    echo "No session $ans" >&2; return 1
  fi
}

cmd_se() {
  local op=${1:-} name="${*:2}" id s
  id=$(cur_id); s=$(session_of "$id")
  needs_session() { [ -n "$s" ] || { echo "Not in a session shell" >&2; exit 1; }; }
  case $op in
    t|T) local args=()
       # A given name wins; else this shell's session; else ask
       if [ -z "$name" ] && [ -z "$s" ]; then
         name=$(ask_session "Session for the new terminal (number or new name): " 1) || return 1
       fi
       [ -n "$name" ] || name=$s
       args=(--session "$name")
       [ "$op" = T ] && gui && args+=(--fraction 0.333)
       cmd_new "${args[@]}" ;;
    d) needs_session; cmd_detach ;;
    s) needs_session; cmd_close_all ;;
    S) needs_session
       read -r -p "Close and kill every shell in $s? [y/N] " a < /dev/tty
       [ "${a,,}" = y ] && cmd_kill_all ;;
    D) needs_session
       read -r -p "End session $s? Its background shells are killed. [y/N] " a < /dev/tty
       [ "${a,,}" = y ] && cmd_end ;;
    m) needs_session; [ -n "$name" ] || name=$(ask_session "Move to (number or new name): " 1 "$s") || return 1
       cmd_move "$name" ;;
    M) needs_session; [ -n "$name" ] || name=$(ask_session "Merge $s into: " 0 "$s") || return 1
       cmd_merge "$name" M ;;
    c) needs_session; [ -n "$name" ] || { read -r -p "Clone $s as: " name < /dev/tty && [ -n "$name" ]; } || return 1
       cmd_clone "$name" c ;;
    C) needs_session; [ -n "$name" ] || name=$(ask_session "Clone $s into: " 0 "$s") || return 1
       cmd_clone "$name" C ;;
    /|o|open) [ -n "$name" ] || name=$(ask_session "Open session: " 0) || return 1
       cmd_open "$name" ;;
    r) needs_session; [ -n "$name" ] || { read -r -p "Rename $s to: " name < /dev/tty && [ -n "$name" ]; } || return 1
       cmd_merge "$name" r ;;
    ls) db -r '.shells | to_entries | group_by(.value.session)[] |
          "\(.[0].value.session)\n" + (map("  \(.key)  \(.value.cwd)\(if .value.open then "" else "  (background)" end)") | join("\n"))'
        [ -n "$s" ] && echo "this shell: $id in $s" ;;
    *) se_help ;;
  esac
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
  session-new) cmd_session_new "${1:-}" ;;
  new-in) cmd_new --session "$1" ;;
  new3-in) cmd_new --session "$1" --fraction 0.333 ;;
  attach) cmd_attach "$@" ;;
  detach) cmd_detach ;;
  end) cmd_end ;;
  close-all) cmd_close_all ;;
  kill-all) cmd_kill_all ;;
  focus) cmd_focus ;;
  move) cmd_move "$1" ;;
  merge) cmd_merge "$1" M ;;
  rename) cmd_merge "$1" r ;;
  clone) cmd_clone "$1" c ;;
  join) cmd_clone "$1" C ;;
  se) cmd_se "$@" ;;
  open) cmd_open "$1" ;;
  list) cmd_list ;;
  prompt) cmd_prompt "$1" ;;
  save) cmd_save ;;
  restore) cmd_restore ;;
  *) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1 ;;
esac

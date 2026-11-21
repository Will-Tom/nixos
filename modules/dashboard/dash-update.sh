#!/usr/bin/env bash
# System update backend for the noctalia dashboard Updates widget.
# The update flow, split into steps the panel buttons call:
#
#   dash-update check     update flake inputs on a scratch copy and build the
#                         new system (no switch); writes the nvd diff
#   dash-update apply     copy the new flake.lock into /etc/nixos and switch
#                         through the root dashboard-apply service (polkit
#                         password prompt), then check if a reboot is needed
#   dash-update discard   drop the preview; /etc/nixos is untouched
#   dash-update reconcile mark a check/apply that died midway as failed
#
# Inputs named in ~/.local/state/dashboard/hold (one per line, # comments)
# are left at their locked version by check, e.g. while upstream is broken.
#
# check and apply run in their own transient user unit (dash-update.service)
# so a noctalia restart during a switch doesn't kill them, and two can't
# run at once. Everything the panel shows is a file in $DIR:
#   state       idle | checking | ready | check-failed | applying | applied | apply-failed
#   log         output of the current step
#   real.txt    nvd [U]/[A]/[R] lines (real version changes)
#   full.txt    the full nvd diff
#   summary     "churn|closure size line"
#   reboot.txt  kernel/systemd lines that changed vs. the booted system

set -uo pipefail
FLAKE=/etc/nixos
DIR=${XDG_RUNTIME_DIR:-/run/user/$UID}/dash-update
STATE=$HOME/.local/state/dashboard
UNIT=dash-update
mkdir -p "$DIR" "$STATE"

state() { echo "$1" > "$DIR/state"; }
current() { cat "$DIR/state" 2>/dev/null || echo idle; }

# Run "$0 _<step>" in a transient unit; fails if one is already running.
spawn() {
  systemctl --user reset-failed "$UNIT.service" 2>/dev/null
  systemd-run --user --collect --quiet --unit="$UNIT" \
    -p Environment="PATH=$PATH" -- "$(realpath "$0")" "_$1"
}

reboot_pat='^\[[UAR.*]+\][[:space:]]+#[0-9]+[[:space:]]+(linux|linux-modules|systemd|systemd-minimal|systemd-minimal-libs)[[:space:]]'

case "${1:-}" in
  check)
    case $(current) in checking|applying) exit 0 ;; esac
    spawn check
    ;;

  _check)
    state checking
    rm -rf "$DIR/flake" "$DIR"/{real.txt,full.txt,summary,reboot.txt}
    exec > "$DIR/log" 2>&1
    echo "Updating flake inputs on a scratch copy…"
    mkdir -p "$DIR/flake" && cp -r "$FLAKE"/. "$DIR/flake/"
    git -C "$DIR/flake" add -A >/dev/null 2>&1 || true
    # Inputs listed in $STATE/hold (one per line) stay at their locked
    # version, e.g. while upstream is broken
    held=$(grep -vE '^\s*(#|$)' "$STATE/hold" 2>/dev/null | xargs)
    if [ -n "$held" ]; then
      echo "Holding back: $held (edit $STATE/hold to release)"
      inputs=$(jq -r --arg h " $held " '.nodes.root.inputs | keys[] | . as $k | select($h | contains(" " + $k + " ") | not)' \
        "$DIR/flake/flake.lock" | xargs)
    else
      inputs=""
    fi
    if [ -n "$held" ] && [ -z "$inputs" ]; then
      echo "Every input is held back; nothing to update."
    # shellcheck disable=SC2086
    elif ! nix flake update $inputs --flake "$DIR/flake"; then
      state check-failed; exit 1
    fi
    echo
    echo "Building new system closure (not switching)…"
    if ! nix build "$DIR/flake#nixosConfigurations.nixos.config.system.build.toplevel" \
          -o "$DIR/result"; then
      state check-failed; exit 1
    fi
    date '+%Y-%m-%d %H:%M' > "$STATE/last-preview"
    nvd diff /run/current-system "$DIR/result" > "$DIR/full.txt" 2>&1 || true
    grep -E '^\[(U|A|R)' "$DIR/full.txt" > "$DIR/real.txt" || true
    churn=$(grep -cE '^\[C' "$DIR/full.txt" || true)
    closure=$(grep -E 'Closure size' "$DIR/full.txt" | head -1 | xargs)
    echo "$churn|$closure" > "$DIR/summary"
    state ready
    ;;

  apply)
    case $(current) in ready|apply-failed) ;; *) echo "nothing to apply" >&2; exit 1 ;; esac
    [ -e "$DIR/flake/flake.lock" ] || { echo "no preview" >&2; exit 1; }
    spawn apply
    ;;

  _apply)
    state applying
    exec > "$DIR/log" 2>&1
    cp "$FLAKE/flake.lock" "$DIR/flake.lock.before"
    cp "$DIR/flake/flake.lock" "$FLAKE/flake.lock"
    echo "Switching (enter your password in the prompt)…"
    # Blocks until the root service finishes; its output goes to /run/dashboard/apply.log
    if systemctl start dashboard-apply.service; then
      git -C "$FLAKE" add flake.lock >/dev/null 2>&1 || true
      echo "Switched. Updated flake.lock staged (committed on next backup)."
      nvd diff /run/booted-system /run/current-system 2>/dev/null \
        | grep -E "$reboot_pat" > "$DIR/reboot.txt" || true
      rm -rf "$DIR/flake" "$DIR/result"
      state applied
    else
      cp "$DIR/flake.lock.before" "$FLAKE/flake.lock"
      echo "Switch failed or was cancelled; flake.lock restored."
      state apply-failed
    fi
    ;;

  discard)
    case $(current) in checking|applying) exit 1 ;; esac
    rm -rf "$DIR/flake" "$DIR/result" "$DIR"/{real.txt,full.txt,summary,reboot.txt,log}
    state idle
    ;;

  reconcile)
    if ! systemctl --user -q is-active "$UNIT.service"; then
      case $(current) in
        checking) state check-failed; echo "(interrupted)" >> "$DIR/log" ;;
        applying) state apply-failed; echo "(interrupted)" >> "$DIR/log" ;;
      esac
    fi
    ;;

  *)
    echo "usage: dash-update check|apply|discard|reconcile" >&2
    exit 1
    ;;
esac

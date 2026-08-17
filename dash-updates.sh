#!/usr/bin/env bash
# Update preview pane — one-shot, interactive, non-destructive.
#
# On open: shows how far behind you are, waits for ENTER (fast; close to skip).
# Then: updates flake inputs on a throwaway copy, builds the new system
# closure WITHOUT switching, and shows only the real version changes
# (upgrades / additions / removals) with nvd's own coloring preserved.
# Closure-only churn is hidden but viewable. You then choose to apply or
# discard. Your real /etc/nixos/flake.lock is only touched if you apply.

set -uo pipefail
FLAKE=/etc/nixos
STATE=/persist/home/willisk/.local/state/dashboard
mkdir -p "$STATE"

bold()  { printf '\033[1m%s\033[0m\n'  "$1"; }
dim()   { printf '\033[2m%s\033[0m\n'  "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }

cleanup() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; }
trap cleanup EXIT

clear
bold "──────────── SYSTEM UPDATES ────────────"
echo

cur_rev=$(nix flake metadata "$FLAKE" --json 2>/dev/null \
  | jq -r '.locks.nodes.nixpkgs.locked.rev // "unknown"' 2>/dev/null)
dim "Locked nixpkgs:    ${cur_rev:0:12}"
dim "Last full preview: $(cat "$STATE/last-preview" 2>/dev/null || echo never)"
echo
yellow "Press ENTER to build an update preview (slow, needs network)."
yellow "Close this window to skip."
read -r _

echo
bold "Updating flake inputs on a scratch copy…"
TMP=$(mktemp -d)
cp -r "$FLAKE"/. "$TMP"/ 2>/dev/null
git -C "$TMP" add -A >/dev/null 2>&1 || true
nix flake update --flake "$TMP" 2>&1 | sed 's/^/  /'

echo
bold "Building new system closure (not switching)…"
if ! nix build "$TMP#nixosConfigurations.nixos.config.system.build.toplevel" \
      -o "$TMP/result" 2>&1 | sed 's/^/  /'; then
  echo
  red "Build failed — nothing changed. See output above."
  echo; dim "Press ENTER to close."; read -r _
  exit 1
fi

date '+%Y-%m-%d %H:%M' > "$STATE/last-preview"

# Two renderings of the SAME diff:
#   nvd.plain  — no escape codes, for matching / counting (reliable)
#   nvd.color  — nvd's own coloring, for display (pretty + informative)
# Line numbers correspond 1:1 between the two, so we find real-change lines
# in the plain file and print those exact lines from the colored file.
nvd diff /run/current-system "$TMP/result" > "$TMP/nvd.plain" 2>&1 || true
if ! nvd --color=always diff /run/current-system "$TMP/result" > "$TMP/nvd.color" 2>&1; then
  cp "$TMP/nvd.plain" "$TMP/nvd.color"
fi

echo
bold "──────────── REAL CHANGES ────────────"
if grep -qE '^\[(U|A|R)' "$TMP/nvd.plain"; then
  grep -nE '^\[(U|A|R)' "$TMP/nvd.plain" | cut -d: -f1 | while read -r n; do
    sed -n "${n}p" "$TMP/nvd.color"
  done | sed 's/^/  /'
else
  dim "  No version changes — only closure dedup / rebuilds."
fi
echo

grep -E 'Closure size' "$TMP/nvd.plain" | sed 's/^/  /'
churn=$(grep -cE '^\[C' "$TMP/nvd.plain" || true)
echo
dim "  ($churn closure-only changes hidden — press v to view the full diff)"
echo

yellow "Apply these updates?   [y] switch    [v] view full diff    [N] discard"
read -r ans
if [ "${ans,,}" = "v" ]; then
  less -R "$TMP/nvd.color"
  yellow "Apply now?   [y] switch    [N] discard"
  read -r ans
fi

if [ "${ans,,}" = "y" ]; then
  cp "$TMP/flake.lock" "$FLAKE/flake.lock"
  git -C "$FLAKE" add flake.lock >/dev/null 2>&1 || true
  echo
  if sudo nixos-rebuild switch --flake "$FLAKE#nixos"; then
    echo
    green "Switched. Updated flake.lock staged (committed on next backup)."
    reboot_bits=$(nvd diff /run/booted-system /run/current-system 2>/dev/null \
                  | grep -E '(^|\s)(linux|systemd)\b' || true)
    echo
    if [ -n "$reboot_bits" ]; then
      yellow "⚠ Kernel/systemd changed — a reboot is recommended:"
      echo "$reboot_bits" | sed 's/^/    /'
    else
      green "No kernel/systemd change — no reboot needed."
    fi
  else
    echo
    red "Switch failed — see output above. flake.lock was copied but not committed."
  fi
else
  yellow "Discarded. Your real flake.lock was not touched."
fi

echo
dim "Press ENTER to close."
read -r _

#!/usr/bin/env bash
set -uo pipefail
FLAKE=/etc/nixos
STATE=/persist/home/willisk/.local/state/dashboard
mkdir -p "$STATE"

bold()  { printf '\033[1m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }

clear
bold "──────────── SYSTEM UPDATES ────────────"
echo

# Current locked nixpkgs rev vs upstream, cheap check (no build).
cur_rev=$(nix flake metadata "$FLAKE" --json 2>/dev/null \
  | ${JQ:-jq} -r '.locks.nodes.nixpkgs.locked.rev // "unknown"' 2>/dev/null)
dim "Locked nixpkgs: ${cur_rev:0:12}"

last_preview=$(cat "$STATE/last-preview" 2>/dev/null || echo "never")
dim "Last full preview: $last_preview"
echo
yellow "Press ENTER to build a preview of pending updates (slow, needs network)."
yellow "Ctrl-C or close this window to skip."
read -r _

echo
bold "Updating flake inputs on a scratch copy…"
TMP=$(mktemp -d)
cp -r "$FLAKE"/. "$TMP"/ 2>/dev/null
# ensure the scratch copy is a usable flake
git -C "$TMP" add -A >/dev/null 2>&1 || true
nix flake update --flake "$TMP" 2>&1 | sed 's/^/  /'

echo
bold "Building new system closure (not switching)…"
if nix build "$TMP#nixosConfigurations.nixos.config.system.build.toplevel" \
      -o "$TMP/result" 2>&1 | sed 's/^/  /'; then
  echo
  bold "──────────── PENDING CHANGES ────────────"
  nvd diff /run/current-system "$TMP/result" || true
  date '+%Y-%m-%d %H:%M' > "$STATE/last-preview"
  echo
  green "Apply these updates now?  [y] switch   [N] discard"
  read -r ans
  if [ "${ans,,}" = "y" ]; then
    # copy the updated lock back into the real flake, then switch
    cp "$TMP/flake.lock" "$FLAKE/flake.lock"
    git -C "$FLAKE" add flake.lock >/dev/null 2>&1 || true
    sudo nixos-rebuild switch --flake "$FLAKE#nixos"
    green "Done. Updated flake.lock committed on next backup."
  else
    yellow "Discarded. Your real flake.lock was not touched."
  fi
else
  red "Build failed — nothing changed. See output above."
fi

rm -rf "$TMP"
echo
dim "Press ENTER to close."
read -r _

#!/usr/bin/env bash
# Fast on open: shows how far behind you are, waits for ENTER.
# Then builds a preview, shows ONLY real version changes (not closure churn),
# and lets you apply or discard. Nothing touches your real flake.lock unless
# you choose to apply.

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

cur_rev=$(nix flake metadata "$FLAKE" --json 2>/dev/null \
  | jq -r '.locks.nodes.nixpkgs.locked.rev // "unknown"' 2>/dev/null)
dim "Locked nixpkgs: ${cur_rev:0:12}"
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
  red "Build failed — nothing changed. See output above."
  rm -rf "$TMP"
  echo; dim "Press ENTER to close."; read -r _; exit 1
fi

# Full diff to a file (plain, for grepping) and a colored copy (for viewing).
nvd diff /run/current-system "$TMP/result" > "$TMP/nvd.out" 2>&1 || true
nvd --color=always diff /run/current-system "$TMP/result" > "$TMP/nvd.color" 2>&1 || cp "$TMP/nvd.out" "$TMP/nvd.color"
date '+%Y-%m-%d %H:%M' > "$STATE/last-preview"

echo
bold "──────────── REAL CHANGES ────────────"
if grep -qE '^\[(U|A|R)' "$TMP/nvd.out"; then
  # Color the filtered lines ourselves so it works regardless of nvd version:
  # upgrades + additions green, removals red.
  grep -E '^\[U' "$TMP/nvd.out" | sed 's/^/  /' | while IFS= read -r l; do green "$l"; done
  grep -E '^\[A' "$TMP/nvd.out" | sed 's/^/  /' | while IFS= read -r l; do green "$l"; done
  grep -E '^\[R' "$TMP/nvd.out" | sed 's/^/  /' | while IFS= read -r l; do red   "$l"; done
else
  dim "  No version changes — only closure dedup / rebuilds."
fi
echo
grep -E 'Closure size' "$TMP/nvd.out" | sed 's/^/  /'
echo
churn=$(grep -cE '^\[C' "$TMP/nvd.out")
dim "  ($churn closure-only changes hidden — press v then ENTER to view full diff)"
echo

yellow "Apply these updates?  [y] switch   [v] view full diff first   [N] discard"
read -r ans
if [ "${ans,,}" = "v" ]; then
  less -R "$TMP/nvd.color"
  yellow "Apply now?  [y] switch   [N] discard"
  read -r ans
fi

if [ "${ans,,}" = "y" ]; then
  cp "$TMP/flake.lock" "$FLAKE/flake.lock"
  git -C "$FLAKE" add flake.lock >/dev/null 2>&1 || true
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
    red "Switch failed — see output above. flake.lock was copied but not committed."
  fi
else
  yellow "Discarded. Your real flake.lock was not touched."
fi

rm -rf "$TMP"
echo
dim "Press ENTER to close."
read -r _

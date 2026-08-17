#!/usr/bin/env bash
# Update preview pane — one-shot, interactive, non-destructive.
#
# On open: shows how far behind you are, waits for ENTER (fast; close to skip).
# Then: updates flake inputs on a throwaway copy, builds the new system
# closure WITHOUT switching, and shows only the real version changes
# (upgrades / additions / removals) with nvd's own coloring preserved.
# Closure-only churn is hidden but viewable. You then choose to apply or
# discard. Your real /etc/nixos/flake.lock is only touched if you apply.
# After applying, checks whether the kernel or systemd changed on the live
# system and, if so, recommends a reboot.

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

# Print the lines of $2 (colored file) whose line numbers match $1 (a grep
# -E pattern) in $3 (plain file). Matching is done on the plain text so it
# is reliable; display comes from the colored file so nvd's coloring shows.
print_matching_colored() {
  local pattern="$1" color_file="$2" plain_file="$3" indent="${4:-  }"
  grep -nE "$pattern" "$plain_file" | cut -d: -f1 | while read -r n; do
    sed -n "${n}p" "$color_file"
  done | sed "s/^/${indent}/"
}

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

# Two renderings of the SAME diff (line numbers correspond 1:1):
#   nvd.plain  — no escape codes, for matching / counting
#   nvd.color  — nvd's own coloring, for display
nvd diff /run/current-system "$TMP/result" > "$TMP/nvd.plain" 2>&1 || true
if ! nvd --color=always diff /run/current-system "$TMP/result" > "$TMP/nvd.color" 2>&1; then
  cp "$TMP/nvd.plain" "$TMP/nvd.color"
fi

echo
bold "──────────── REAL CHANGES ────────────"
if grep -qE '^\[(U|A|R)' "$TMP/nvd.plain"; then
  print_matching_colored '^\[(U|A|R)' "$TMP/nvd.color" "$TMP/nvd.plain" "  "
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

    # Reboot check: does the RUNNING system differ from the just-activated one
    # in the kernel or systemd? Same plain/color two-file trick for coloring.
    nvd diff /run/booted-system /run/current-system > "$TMP/reboot.plain" 2>/dev/null || true
    if ! nvd --color=always diff /run/booted-system /run/current-system > "$TMP/reboot.color" 2>/dev/null; then
      cp "$TMP/reboot.plain" "$TMP/reboot.color"
    fi
    # Only the actual kernel and systemd proper warrant a reboot — not
    # linux-headers, linux-pam, etc. Match the package name at line start.
    reboot_pat='^\[[UAR.*]+\][[:space:]]+#[0-9]+[[:space:]]+(linux|linux-modules|systemd|systemd-minimal|systemd-minimal-libs)[[:space:]]'
    echo
    if grep -qE "$reboot_pat" "$TMP/reboot.plain"; then
      yellow "⚠ Kernel/systemd changed — a reboot is recommended:"
      print_matching_colored "$reboot_pat" "$TMP/reboot.color" "$TMP/reboot.plain" "    "
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

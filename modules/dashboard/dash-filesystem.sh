#!/usr/bin/env bash
# Filesystem health pane btrfs error stats, last scrub,
# btrbk snapshots, drive usage. Read-only. Runs once, waits to close.

set -uo pipefail
bold()  { printf '\033[1m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }

clear
bold "──────────── FILESYSTEM HEALTH ────────────"
echo

bold "btrfs error counters (/persist)"
stats=$(sudo btrfs device stats /persist 2>/dev/null)
if [ -n "$stats" ]; then
  echo "$stats" | sed 's/^/  /'
  if echo "$stats" | grep -qE ' [1-9][0-9]*$'; then
    red "  ⚠ non-zero error counters — investigate"
  else
    green "  all counters zero ✓"
  fi
else
  red "  could not read stats"
fi
echo

bold "Last scrub"
for fs in /nix /persist; do
  line=$(sudo btrfs scrub status "$fs" 2>/dev/null | grep -iE 'status|errors' | tr '\n' ' ')
  printf '  %-9s %s\n' "$fs" "$line"
done
echo

bold "btrbk snapshots (/persist/.snapshots)"
if [ -d /persist/.snapshots ]; then
  count=$(find /persist/.snapshots -maxdepth 1 -type d 2>/dev/null | tail -n +2 | wc -l)
  newest=$(ls -1t /persist/.snapshots 2>/dev/null | head -1)
  oldest=$(ls -1t /persist/.snapshots 2>/dev/null | tail -1)
  printf '  count:  %s\n' "$count"
  printf '  newest: %s\n' "${newest:-none}"
  printf '  oldest: %s\n' "${oldest:-none}"
  tstate=$(systemctl is-active btrbk-persist.timer 2>/dev/null || echo unknown)
  if [ "$tstate" = active ]; then green "  timer: active ✓"; else red "  timer: $tstate ⚠"; fi
else
  red "  /persist/.snapshots missing"
fi
echo

bold "Drive usage"
sudo btrfs filesystem usage -h /persist 2>/dev/null \
  | grep -iE 'Device size|Used|Free \(estimated\)' | sed 's/^/  /'
echo
dim "  physical devices:"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT -e7 2>/dev/null | grep -E 'nvme|NAME' | sed 's/^/  /'
echo

dim "checked $(date '+%Y-%m-%d %H:%M:%S')"
echo
dim "Press ENTER to close."
read -r _

#!/usr/bin/env bash
# Filesystem health as JSON for the noctalia dashboard Filesystem widget.
# Same checks as dash-filesystem.sh. Needs root (btrfs ioctls), so it runs
# from the dashboard-fs-status system timer and writes /run/dashboard/fs.json.

set -uo pipefail
out=/run/dashboard/fs.json

stats=$(btrfs device stats /persist 2>/dev/null \
  | awk '{ n = split($1, p, "."); printf "{\"counter\":\"%s\",\"value\":%d}\n", p[n], $2 }' | jq -s '.')

scrub=$(for fs in /nix /persist; do
  s=$(btrfs scrub status "$fs" 2>/dev/null)
  jq -n --arg fs "$fs" \
        --arg status "$(grep -iE '^Status:' <<<"$s" | cut -d: -f2- | xargs)" \
        --arg started "$(grep -iE '^Scrub started:' <<<"$s" | cut -d: -f2- | xargs)" \
        --arg errors "$(grep -iE '^Error summary:' <<<"$s" | cut -d: -f2- | xargs)" \
        --argjson never "$(grep -q 'no stats available' <<<"$s" && echo true || echo false)" \
        '{fs: $fs, status: $status, started: $started, errors: $errors, never: $never}'
done | jq -s '.')

snapdir=/persist/.snapshots
names=$(ls -1 "$snapdir" 2>/dev/null | sort)
snapshots=$(jq -n --argjson exists "$([ -d "$snapdir" ] && echo true || echo false)" \
  --argjson count "$(grep -c . <<<"$names")" \
  --arg newest "$(tail -1 <<<"$names")" --arg oldest "$(head -1 <<<"$names")" \
  --arg timer "$(systemctl is-active btrbk-persist.timer 2>/dev/null)" \
  '{exists: $exists, count: $count, newest: $newest, oldest: $oldest, timer: $timer}')

u=$(btrfs filesystem usage -h /persist 2>/dev/null)
usage=$(jq -n \
  --arg size "$(grep -E '^\s*Device size:' <<<"$u" | awk '{print $3}')" \
  --arg used "$(grep -E '^\s*Used:' <<<"$u" | head -1 | awk '{print $2}')" \
  --arg free "$(grep -E '^\s*Free \(estimated\):' <<<"$u" | awk '{print $3}')" \
  '{size: $size, used: $used, free: $free}')

devices=$(lsblk -J -o NAME,SIZE,FSTYPE,MOUNTPOINT -e7 2>/dev/null \
  | jq '[.blockdevices[] | select(.name | test("nvme")) | {name, size,
         parts: [.. | objects | select(.fstype != null) | "\(.name) \(.fstype)"]}]')

mkdir -p "$(dirname "$out")"
jq -n --argjson stats "${stats:-[]}" --argjson scrub "$scrub" --argjson snapshots "$snapshots" \
      --argjson usage "$usage" --argjson devices "${devices:-[]}" \
      --arg checked "$(date '+%Y-%m-%d %H:%M')" \
      '{stats: $stats, errors: ([$stats[].value] | add // 0), scrub: $scrub,
        snapshots: $snapshots, usage: $usage, devices: $devices, checked: $checked}' \
  > "$out.tmp" && chmod 644 "$out.tmp" && mv "$out.tmp" "$out"

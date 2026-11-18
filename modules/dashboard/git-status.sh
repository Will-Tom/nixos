#!/usr/bin/env bash
# Git backup status as JSON for the noctalia dashboard Git widget.
# Checks /etc/nixos and every repo under ~/Projects
# (dirty/ahead/behind, last commit and its size), plus backup service/timer health.

set -uo pipefail

repo_json() {
  local dir="$1" name="$2"
  if [ ! -d "$dir/.git" ]; then
    jq -n --arg name "$name" '{name: $name, error: "no .git"}'
    return
  fi
  local dirty counts ahead behind last size
  dirty=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l)
  git -C "$dir" fetch --quiet 2>/dev/null || true
  counts=$(git -C "$dir" rev-list --left-right --count 'HEAD...@{u}' 2>/dev/null || printf '0\t0')
  ahead=$(cut -f1 <<<"$counts")
  behind=$(cut -f2 <<<"$counts")
  last=$(git -C "$dir" log -1 --format='%cr' 2>/dev/null || echo "?")
  size=$(git -C "$dir" show --stat --oneline HEAD 2>/dev/null | tail -1 \
         | grep -oE '[0-9]+ insertion|[0-9]+ deletion' | paste -sd', ' -)
  jq -n --arg name "$name" --arg last "$last" --arg size "$size" \
        --argjson dirty "${dirty:-0}" --argjson ahead "${ahead:-0}" --argjson behind "${behind:-0}" \
        '{name: $name, dirty: $dirty, ahead: $ahead, behind: $behind, last: $last, size: $size}'
}

service_json() {
  local unit="$1" label="$2" act result last
  act=$(systemctl is-active "$unit" 2>/dev/null)
  result=$(systemctl show "$unit" -p Result --value 2>/dev/null)
  last=$(systemctl show "$unit" -p ExecMainExitTimestamp --value 2>/dev/null | awk '{print $2, $3}')
  jq -n --arg label "$label" --arg state "${act:--}/${result:--}" --arg last "$last" \
        --argjson ok "$([ "$result" = success ] || [ "$act" = active ] && echo true || echo false)" \
        '{label: $label, ok: $ok, state: $state, last: $last}'
}

timer_json() {
  local st
  st=$(systemctl is-active "$1" 2>/dev/null)
  jq -n --arg name "$1" --arg state "${st:-unknown}" '{name: $name, ok: ($state == "active"), state: $state}'
}

{
  repo_json /etc/nixos nixos-config
  for d in "$HOME"/Projects/*/; do
    [ -d "$d/.git" ] && repo_json "${d%/}" "$(basename "$d")"
  done
} | jq -s '.' > "${TMPDIR:-/tmp}/git-status.repos.$$"

{
  service_json gitBackup.service                "nixos → GitHub"
  service_json gitBackup-ObsidianBackup.service "ObsidianBackup"
  service_json gitBackup-GalaxySlayer.service   "GalaxySlayer"
} | jq -s '.' > "${TMPDIR:-/tmp}/git-status.svc.$$"

{
  timer_json gitBackup-ObsidianBackup.timer
  timer_json gitBackup-GalaxySlayer.timer
} | jq -s '.' > "${TMPDIR:-/tmp}/git-status.timers.$$"

jq -n --slurpfile repos "${TMPDIR:-/tmp}/git-status.repos.$$" \
      --slurpfile services "${TMPDIR:-/tmp}/git-status.svc.$$" \
      --slurpfile timers "${TMPDIR:-/tmp}/git-status.timers.$$" \
      --arg checked "$(date '+%Y-%m-%d %H:%M')" \
      '{repos: $repos[0], services: $services[0], timers: $timers[0], checked: $checked}'
rm -f "${TMPDIR:-/tmp}"/git-status.*.$$

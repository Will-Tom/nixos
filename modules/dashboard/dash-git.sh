#!/usr/bin/env bash
# Scans /etc/nixos and every repo under ~/Projects: dirty/ahead state,
# last commit + diffstat size, and backup service/timer health.

set -uo pipefail
bold()  { printf '\033[1m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }

report_repo() {
  local dir="$1" label="$2"
  [ -d "$dir/.git" ] || { printf '  %-16s ' "$label"; red "no .git"; return; }
  git -C "$dir" config --global --add safe.directory "$dir" >/dev/null 2>&1 || true

  local dirty ahead behind counts last size
  dirty=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l)
  git -C "$dir" fetch --quiet 2>/dev/null || true
  counts=$(git -C "$dir" rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo "0	0")
  ahead=$(echo "$counts"  | cut -f1)
  behind=$(echo "$counts" | cut -f2)
  last=$(git -C "$dir" log -1 --format='%cr' 2>/dev/null || echo "?")
  size=$(git -C "$dir" show --stat --oneline HEAD 2>/dev/null \
         | tail -1 | grep -oE '[0-9]+ insertion|[0-9]+ deletion' | paste -sd', ' - )

  printf '  %-16s ' "$label"
  if [ "$dirty" -eq 0 ] && [ "${ahead:-0}" -eq 0 ]; then
    green "clean, pushed ✓"
  else
    local msg=""
    [ "$dirty" -ne 0 ]       && msg+="${dirty} uncommitted "
    [ "${ahead:-0}" -ne 0 ]  && msg+="${ahead} unpushed "
    [ "${behind:-0}" -ne 0 ] && msg+="${behind} behind "
    red "$msg"
  fi
  dim "                   last: $last  ${size:+($size)}"
}

svc_state() {
  local unit="$1" label="$2" act result last
  act=$(systemctl is-active "$unit" 2>/dev/null || echo "-")
  result=$(systemctl show "$unit" -p Result --value 2>/dev/null || echo "-")
  last=$(systemctl show "$unit" -p ExecMainExitTimestamp --value 2>/dev/null | awk '{print $2, $3}')
  printf '  %-22s ' "$label"
  if [ "$result" = success ] || [ "$act" = active ]; then green "ok"; else red "$act/$result"; fi
  [ -n "${last// }" ] && dim "                       last run: $last"
}

clear
bold "──────────── GIT BACKUP STATUS ────────────"
echo

bold "Repositories"
report_repo /etc/nixos "nixos-config"
if [ -d "$HOME/Projects" ]; then
  for d in "$HOME"/Projects/*/; do
    [ -d "$d/.git" ] || continue
    report_repo "${d%/}" "$(basename "$d")"
  done
fi
echo

bold "Backup services"
svc_state "gitBackup.service"                "nixos → GitHub"
svc_state "gitBackup-ObsidianBackup.service" "ObsidianBackup"
svc_state "gitBackup-GalaxySlayer.service"   "GalaxySlayer"
echo

bold "Backup timers"
for t in gitBackup-ObsidianBackup.timer gitBackup-GalaxySlayer.timer; do
  st=$(systemctl is-active "$t" 2>/dev/null || echo unknown)
  printf '  %-30s ' "$t"
  if [ "$st" = active ]; then green "active ✓"; else red "$st ⚠"; fi
done
echo

dim "checked $(date '+%Y-%m-%d %H:%M:%S')"
echo
dim "Press ENTER to close."
read -r _

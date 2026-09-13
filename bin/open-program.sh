#!/bin/bash
# Opens the workout page in the default browser once per day. Safe to run as
# often as you like: a stamp file holds the date it last opened the page and
# the script exits early on the same day. The daily reminder is a separate
# script (daily-reminder.sh); the LaunchAgent runs both.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
url_file="$here/../pages-url.txt"
state_dir="$HOME/.local/state/workout"
stamp="$state_dir/last-open"
log_file="$HOME/Library/Logs/workout.log"
today="$(date +%Y-%m-%d)"
mkdir -p "$state_dir" "$(dirname "$log_file")"

log() {
  local line; line="$(date '+%Y-%m-%d %H:%M:%S') open: $*"
  echo "$line" >> "$log_file"
  [ -t 1 ] && echo "$line"
  return 0
}

if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$today" ]; then
  exit 0
fi

url="$(tr -d '[:space:]' < "$url_file" 2>/dev/null || true)"
case "$url" in
  http*) ;;
  *) log "no Pages URL in $url_file"; exit 1 ;;
esac

if open "$url"; then
  echo "$today" > "$stamp"
  log "opened $url"
else
  log "could not open $url"; exit 1
fi

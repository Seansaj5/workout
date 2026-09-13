#!/bin/bash
# Once a day: open the workout page in the default browser, and add a
# "Workout: <session>" reminder (due 5pm) to the default Reminders list.
# Run by the com.sean.workout LaunchAgent at login and at 06:00 (or on the
# first wake after 06:00). Safe to run as often as you like: each part keeps
# a stamp file holding the date it last ran and exits early on the same day.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
url_file="$here/../pages-url.txt"
state_dir="$HOME/.local/state/workout"
open_stamp="$state_dir/last-open"
reminder_stamp="$state_dir/last-reminder"
today="$(date +%Y-%m-%d)"
mkdir -p "$state_dir"

# One run at a time. A run can sit for minutes waiting on the Reminders
# permission prompt; a second run started meanwhile must not double up.
lock="$state_dir/lock"
if ! mkdir "$lock" 2>/dev/null; then
  other="$(cat "$lock/pid" 2>/dev/null || true)"
  if [ -n "$other" ] && kill -0 "$other" 2>/dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') another run is already in progress (pid $other), exiting"
    exit 0
  fi
  rm -rf "$lock" && mkdir "$lock" || exit 1   # stale lock from a killed run
fi
echo $$ > "$lock/pid"
trap 'rm -rf "$lock"' EXIT

done_today() { [ -f "$1" ] && [ "$(cat "$1")" = "$today" ]; }
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

status=0

# 1. Open the page, once per day.
if ! done_today "$open_stamp"; then
  url="$(tr -d '[:space:]' < "$url_file" 2>/dev/null || true)"
  case "$url" in
    http*)
      if open "$url"; then
        echo "$today" > "$open_stamp"
        log "opened $url"
      else
        log "could not open $url" >&2; status=1
      fi ;;
    *) log "no Pages URL in $url_file yet" >&2; status=1 ;;
  esac
fi

# 2. Reminder, once per day. Same session mapping as the daily workflow.
if ! done_today "$reminder_stamp"; then
  case "$(date +%u)" in   # 1 = Monday ... 7 = Sunday
    1) session="Push" ;;  2) session="Pull" ;;  3) session="Legs" ;;
    4) session="Upper" ;; 5) session="Lower" ;; 6) session="Shape" ;;
    7) session="Rest" ;;
  esac
  body=""
  [ "$session" = "Rest" ] && body="The face and neck routine still happens."

  # The first run prompts for permission to control Reminders. Until it is
  # approved this fails; the stamp is not written, so it retries next run.
  # The script also checks Reminders itself, so even a lost stamp cannot
  # produce a second "Workout: ..." item for the same day.
  if result="$(osascript - "Workout: $session" "$body" <<'APPLESCRIPT'
on run argv
  set theName to item 1 of argv
  set theBody to item 2 of argv
  set dayStart to current date
  set time of dayStart to 0
  set dayEnd to dayStart + 1 * days
  set dueDate to dayStart + 17 * hours
  with timeout of 600 seconds
  tell application "Reminders"
    tell default list
      repeat with r in (every reminder whose name is theName and completed is false)
        try
          set d to due date of r
          if d is not missing value and d is greater than or equal to dayStart and d is less than dayEnd then
            return "already exists"
          end if
        end try
      end repeat
      if theBody is "" then
        make new reminder with properties {name:theName, due date:dueDate, remind me date:dueDate}
      else
        make new reminder with properties {name:theName, body:theBody, due date:dueDate, remind me date:dueDate}
      end if
    end tell
  end tell
  end timeout
  return "created"
end run
APPLESCRIPT
  )"; then
    echo "$today" > "$reminder_stamp"
    log "reminder ${result}: Workout: $session (due 5pm)"
  else
    log "reminder failed. If a Reminders permission prompt appeared, approve it; this retries on the next run." >&2
    status=1
  fi
fi

exit $status

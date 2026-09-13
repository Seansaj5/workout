#!/bin/bash
# Keeps the next 7 days (today included) topped up in the "Workout" list of
# Reminders.app: one item per day, named for that day's session, due 5pm.
#
# Idempotent and self-healing: creates the Workout list if it is missing, and
# for each date asks Reminders whether that day's item already exists before
# creating one. Run it as often as you like; it tops up the window rather
# than piling up copies. The LaunchAgent runs it daily, so the window rolls.
# Exit 0: window is complete. Exit 1: failed; the error is in the log.
set -u

log_file="$HOME/Library/Logs/workout.log"
state_dir="$HOME/.local/state/workout"
mkdir -p "$(dirname "$log_file")" "$state_dir"

log() {
  local line; line="$(date '+%Y-%m-%d %H:%M:%S') reminder: $*"
  echo "$line" >> "$log_file"
  [ -t 1 ] && echo "$line"        # also to the terminal when run by hand
  return 0
}

# One run at a time: a run can sit for minutes on the permission prompt.
lock="$state_dir/reminder.lock"
if ! mkdir "$lock" 2>/dev/null; then
  other="$(cat "$lock/pid" 2>/dev/null || true)"
  if [ -n "$other" ] && kill -0 "$other" 2>/dev/null; then
    log "another run is already in progress (pid $other), exiting"
    exit 0
  fi
  rm -rf "$lock" && mkdir "$lock" || exit 1   # stale lock from a killed run
fi
echo $$ > "$lock/pid"
errors="$(mktemp -t workout-reminder)"
trap 'rm -rf "$lock" "$errors"' EXIT

# Same day mapping as .github/workflows/daily.yml.
session_name() {
  case "$1" in
    Monday)    echo "Workout: Push" ;;
    Tuesday)   echo "Workout: Pull" ;;
    Wednesday) echo "Workout: Legs" ;;
    Thursday)  echo "Workout: Upper" ;;
    Friday)    echo "Workout: Lower" ;;
    Saturday)  echo "Workout: Shape" ;;
    Sunday)    echo "Rest day, face and neck only" ;;
    *) return 1 ;;
  esac
}

# One "YYYY-MM-DD|name" entry per day, today first.
entries=()
for offset in 0 1 2 3 4 5 6; do
  day="$(date -v+${offset}d +%A)"
  name="$(session_name "$day")" || { log "unexpected day: $day"; exit 1; }
  entries+=("$(date -v+${offset}d +%Y-%m-%d)|$name")
done

# The first run from any new "responsible" app (Terminal, or the launchd job
# itself) makes macOS ask for permission to control Reminders. The 10 minute
# timeout gives you time to approve it; if it is declined, the error below is
# logged and the exit status is 1.
output="$(mktemp -t workout-reminder-out)"
trap 'rm -rf "$lock" "$errors" "$output"' EXIT
if osascript - "${entries[@]}" >"$output" 2>"$errors" <<'APPLESCRIPT'
on run argv
  set listName to "Workout"
  -- Each argument is "YYYY-MM-DD|name". Build every date up front, from its
  -- calendar parts, so 5pm is 5pm on the wall clock even across a daylight
  -- saving change.
  set names to {}
  set starts to {}
  set ends to {}
  set dues to {}
  repeat with i from 1 to (count argv)
    set e to (item i of argv) as text
    set dayStart to current date
    set day of dayStart to 1
    set year of dayStart to (text 1 thru 4 of e) as integer
    set month of dayStart to (text 6 thru 7 of e) as integer
    set day of dayStart to (text 9 thru 10 of e) as integer
    set time of dayStart to 0
    set dayEnd to dayStart + 36 * hours
    set time of dayEnd to 0
    copy dayStart to dueDate     -- copy: plain assignment would alias the same date object
    set time of dueDate to 17 * hours
    set end of names to (text 12 thru -1 of e)
    set end of starts to dayStart
    set end of ends to dayEnd
    set end of dues to dueDate
  end repeat
  set created to 0
  set existing to 0
  set madeList to ""
  with timeout of 600 seconds
    tell application "Reminders"
      if not (exists list listName) then
        make new list with properties {name:listName}
        set madeList to " (created the Workout list)"
      end if
      set theList to list listName
      repeat with i from 1 to (count names)
        set theName to item i of names
        set dayStart to item i of starts
        set dayEnd to item i of ends
        set found to false
        repeat with r in (every reminder of theList whose name is theName)
          try
            set d to due date of r
            if d is not missing value and d is greater than or equal to dayStart and d is less than dayEnd then
              set found to true
              exit repeat
            end if
          end try
        end repeat
        if found then
          set existing to existing + 1
        else
          tell theList
            make new reminder with properties {name:theName, due date:(item i of dues), remind me date:(item i of dues)}
          end tell
          set created to created + 1
        end if
      end repeat
    end tell
  end timeout
  return "created " & created & ", already there " & existing & madeList
end run
APPLESCRIPT
then
  result="$(tr -d '\n' < "$output")"
  log "7-day window ${entries[0]%%|*} to ${entries[6]%%|*}: $result"
  exit 0
else
  log "FAILED: $(tr '\n' ' ' < "$errors" | sed 's/  */ /g')"
  exit 1
fi

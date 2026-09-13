#!/bin/bash
# Today's reminder in the "Workout" list of Reminders.app, due 5pm.
#
# Idempotent and self-healing: creates the Workout list if it is missing, and
# asks Reminders whether today's item already exists before creating one, so
# it can run any number of times from anywhere without piling up duplicates.
# Exit 0: created or already there. Exit 1: failed; the error is in the log.
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
trap 'rm -rf "$lock"' EXIT

# Same day mapping as .github/workflows/daily.yml.
case "$(date +%A)" in
  Monday)    name="Workout: Push" ;;
  Tuesday)   name="Workout: Pull" ;;
  Wednesday) name="Workout: Legs" ;;
  Thursday)  name="Workout: Upper" ;;
  Friday)    name="Workout: Lower" ;;
  Saturday)  name="Workout: Shape" ;;
  Sunday)    name="Rest day, face and neck only" ;;
  *) log "unexpected day: $(date +%A)"; exit 1 ;;
esac

errors="$(mktemp -t workout-reminder)"
trap 'rm -rf "$lock" "$errors"' EXIT

# The first run from any new "responsible" app (Terminal, or the launchd job
# itself) makes macOS ask for permission to control Reminders. The 10 minute
# timeout gives you time to approve it; if it is declined, the error below is
# logged and the exit status is 1.
if result="$(osascript - "$name" 2>"$errors" <<'APPLESCRIPT'
on run argv
  set theName to item 1 of argv
  set listName to "Workout"
  set dayStart to current date
  set time of dayStart to 0
  set dayEnd to dayStart + 1 * days
  set dueDate to dayStart + 17 * hours
  with timeout of 600 seconds
    tell application "Reminders"
      if not (exists list listName) then
        make new list with properties {name:listName}
      end if
      set theList to list listName
      repeat with r in (every reminder of theList whose name is theName)
        try
          set d to due date of r
          if d is not missing value and d is greater than or equal to dayStart and d is less than dayEnd then
            return "already exists"
          end if
        end try
      end repeat
      tell theList
        make new reminder with properties {name:theName, due date:dueDate, remind me date:dueDate}
      end tell
    end tell
  end timeout
  return "created"
end run
APPLESCRIPT
)"; then
  log "$result: \"$name\" in list Workout, due 5pm"
  exit 0
else
  log "FAILED for \"$name\": $(tr '\n' ' ' < "$errors" | sed 's/  */ /g')"
  exit 1
fi

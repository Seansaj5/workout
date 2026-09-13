# Home Program: how it is wired

Live URL: https://seansaj5.github.io/workout/

## The pieces

| File | Job |
|------|-----|
| `index.html` | The plan. One page, no build step. Picks today's session from the device date. |
| `manifest.json`, `icons/` | Make it installable on the iPhone home screen. |
| `sw.js` | Offline cache for the basement. Network-first for the page, cache-first for icons, manifest and the Google Fonts (stylesheet and font files are precached at install). Other origins, such as the YouTube form links, are never touched. |
| `pages-url.txt` | The one place the live URL is written. The workflow and the open script both read it. |
| `.github/workflows/daily.yml` | 13:00 UTC every day: works out the session in New York time and posts it to ntfy. The topic lives only in the `NTFY_TOPIC` repository secret. |
| `bin/open-program.sh` | Once a day on this Mac: opens the page in the default browser. A stamp file holds the date it last did. |
| `bin/daily-reminder.sh` | Makes sure today's reminder exists in the **Workout** list in Reminders.app, due 5pm: "Workout: Push" and so on, or "Rest day, face and neck only" on Sunday. Creates the list if it is missing and asks Reminders before creating, so it never duplicates. |
| `~/Library/LaunchAgents/com.sean.workout.plist` | Runs both scripts, open first then reminder, at login and at 06:00 (or on the first wake after 06:00). Not in the repo; it holds absolute paths. |

State on this Mac: `~/.local/state/workout/last-open` holds the date the page was last opened. The reminder keeps no stamp; Reminders itself is the record. Both scripts log to `~/Library/Logs/workout.log`.

## Edit the workout plan

1. Edit the `PLAN` object near the bottom of `index.html` (or anything else on the page).
2. Check it locally if you like: `python3 -m http.server` in this folder, then open `http://localhost:8000/`. On this Mac the server takes about half a minute before it answers.
3. Commit and push:

   ```
   git add -A
   git commit -m "Update plan"
   git push
   ```

GitHub Pages redeploys in about a minute. The phone picks up the new page the next time the app is opened with signal. No cache bump is needed for this.

## Bump the service worker cache

Only needed when you change the icons, `manifest.json`, the Google Fonts link (copy the new `<link>` URL into `FONT_CSS` in `sw.js` as well) or `sw.js` itself. Change the constant at the top of `sw.js`:

```
const CACHE_VERSION = 'v2';
```

Push it. On the next open with signal the new worker installs, throws away the old cache and takes over without reinstalling the app.

## The daily notification

- Edit the time: change the cron line in `.github/workflows/daily.yml`. It is UTC only.
- Test it by hand: `gh workflow run daily.yml`, or Actions > Daily session > Run workflow on github.com.
- Change the topic: `gh secret set NTFY_TOPIC`, then subscribe to the new topic in the ntfy app. Never write the topic into a file in this repo.

## The Mac-side open and reminder

- Run them by hand from this folder: `bin/open-program.sh` and `bin/daily-reminder.sh`. A second run of either on the same day does nothing.
- Make the page open again today: `rm ~/.local/state/workout/last-open`.
- The reminder script is safe to run from anywhere, any number of times. It looks in the Workout list for an item with today's exact name and a due date today, completed or not, and only creates one if none is there. Only one copy runs at a time; a run waiting on the permission prompt holds `~/.local/state/workout/reminder.lock` and later runs exit at once.
- If it fails, the exit status is 1 and the real error is in `~/Library/Logs/workout.log`, for example `Not authorized to send Apple events to Reminders. (-1743)`.
- Change the 06:00 time or drop it: edit `StartCalendarInterval` in the plist, then bootout and bootstrap again (below).

### Permission

Controlling Reminders needs an Automation permission, and macOS grants it per "responsible" app. Running the script from Terminal is one identity; the LaunchAgent, which launchd starts on its own, is another. Each gets its own prompt the first time and each needs approving once. Declining leaves a "not authorized" line in the log each run; fix it in System Settings > Privacy & Security > Automation by allowing Reminders under the entry that ran the script. The script waits up to ten minutes for a prompt to be answered.

Disable the LaunchAgent:

```
launchctl bootout gui/$(id -u)/com.sean.workout
```

Turn it back on:

```
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.sean.workout.plist
```

Remove it for good: bootout, then delete `~/Library/LaunchAgents/com.sean.workout.plist`.

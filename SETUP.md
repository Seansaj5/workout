# Home Program: how it is wired

Live URL: https://seansaj5.github.io/workout/

## The pieces

| File | Job |
|------|-----|
| `index.html` | The plan. One page, no build step. Picks today's session from the device date. |
| `manifest.json`, `icons/` | Make it installable on the iPhone home screen. |
| `sw.js` | Offline cache for the basement. Network-first for the page, cache-first for icons, manifest and the Google Fonts. |
| `pages-url.txt` | The one place the live URL is written. The workflow and the open script both read it. |
| `.github/workflows/daily.yml` | 13:00 UTC every day: works out the session in New York time and posts it to ntfy. The topic lives only in the `NTFY_TOPIC` repository secret. |
| `bin/open-program.sh` | Once a day on this Mac: opens the page in the default browser and adds a "Workout: Push" style reminder due 5pm to the default Reminders list. |
| `~/Library/LaunchAgents/com.sean.workout.plist` | Runs that script at login and at 06:00 (or on the first wake after 06:00). Not in the repo; it holds an absolute path. |

State the script keeps: `~/.local/state/workout/last-open` and `last-reminder` hold the date each part last ran. Log: `~/Library/Logs/workout.log`.

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

Only needed when you change the icons, `manifest.json` or `sw.js` itself. Change the constant at the top of `sw.js`:

```
const CACHE_VERSION = 'v2';
```

Push it. On the next open with signal the new worker installs, throws away the old cache and takes over without reinstalling the app.

## The daily notification

- Edit the time: change the cron line in `.github/workflows/daily.yml`. It is UTC only.
- Test it by hand: `gh workflow run daily.yml`, or Actions > Daily session > Run workflow on github.com.
- Change the topic: `gh secret set NTFY_TOPIC`, then subscribe to the new topic in the ntfy app. Never write the topic into a file in this repo.

## The Mac-side open and reminder

- Run it by hand: `bin/open-program.sh`. A second run on the same day does nothing.
- Force it to run again today: `rm ~/.local/state/workout/last-open ~/.local/state/workout/last-reminder`.
- Change the 06:00 time or drop it: edit `StartCalendarInterval` in the plist, then bootout and bootstrap again (below).

Disable the LaunchAgent:

```
launchctl bootout gui/$(id -u)/com.sean.workout
```

Turn it back on:

```
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.sean.workout.plist
```

Remove it for good: bootout, then delete `~/Library/LaunchAgents/com.sean.workout.plist`.

If reminders stop appearing, check `~/Library/Logs/workout.log`. A "not authorized" error means the Reminders automation permission was declined: System Settings > Privacy & Security > Automation, and allow Reminders for the entry that ran the script.

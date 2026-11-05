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
| `bin/daily-reminder.sh` | Keeps the next 7 days topped up in the **Workout** list in Reminders.app: one item per day named for that day's session, "Workout: Push" and so on, or "Rest day, face and neck only" on a Sunday, due 5pm. Creates the list if it is missing and checks each date in Reminders before creating, so it never duplicates. Run daily by the LaunchAgent, the window rolls forward by itself. |
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

## The log, rest timer and progress

- **Logging.** Every lift card has weight and reps steppers. Tapping a set records what the steppers say. The card shows last time's numbers, says when to add 5 lb (top of the range on both sets), shows the plates for a 45 lb bar on barbell lifts, and marks a PR (best estimated max, or reps, seconds or weight for bodyweight, hang and carry moves). How each lift is logged comes from its name: `BW`, `SECS`, `CARRY` and `BARBELL` near the top of the script.
- **Storage.** Logged sets live in `localStorage` under `hp.log`, keyed by date, and are never cleared by the morning reset (the tick marks in `hp` still are). "Clear today's marks" removes today's logged sets too. Settings are in `hp.prefs`. Progress has Export and Import for a JSON backup; import only adds days that are not already on the phone and keeps only known lifts and numbers.
- **Rest timer.** Starts when a set is ticked: 3 minutes after lifts matching `BIG` (presses, squats, deadlifts, rows, pull-ups, chin-ups, lunges, thrusts), 90 seconds otherwise. It counts to a fixed end time, so locking the phone does not lose it. Turn it or its chime off in Progress.
- **Progress.** The flame at the top right: streak (a lifting day counts at half its lifting sets, Sunday at half of everything), this week, volume, PRs, a 16 week heatmap and a trend line per lift.
- **Face and neck.** The block runs every other day by calendar date, counted from 2 Nov 2026 (`isFaceDate`). Off days hide it.
- **Workout mode.** The Start workout button under the day's stats opens a full-screen guided session for today: one exercise at a time, the same steppers, a big Log set button, the rest countdown, and it moves on by itself. It writes the same tick marks and log as the cards, and opens the finish card when the last lifting set is in.
- **Warm-ups.** Barbell lifts at 95 lb or more show a warm-up ramp under the plates: the bar, then about 50, 70 and 85 percent of the working weight (`warmupHTML`).
- **Badges.** `BADGES` near the end of the main script. They are worked out from `hp.log` each time; `hp.badges` only remembers which ones the finish card has already announced.
- **Dock.** The floating glass bar at the bottom: Today (its calendar shows today's date), Workout (opens workout mode; glows while lifts are left, turns into a tick when done), Progress and Spot. Each is a glossy gel tile drawn in inline SVG and CSS (`.ai` and the `--ai-*` gradients), no image files. A glass lens (`.lens`) sits under the open page; drag along the dock and it follows the finger while the icons swell like the old Mac dock, and letting go opens the one under it (the script after `updateDock`). With a mouse the icons swell as the pointer passes. The rest timer rises out of it. Spot's old corner orb is hidden in favour of the dock button.
- **The sky.** Painted once into two canvases by the script block headed `the sky` (`paintSky`: gradient, a few stars, the aqua light with its rays, streak and flare rings, three Vista-style light ribbons made of fine strands, bokeh, haze; `paintLand`: three hills with lit crests). It repaints only when the width changes, never while scrolling. The small moving things sit in the `.amb` block on top: aurora, glints, shooting stars, fireflies, bubbles. Where the browser supports scroll-driven animations the sky and hills move at different speeds as you scroll.
- **Keeping it smooth.** Real blur (`backdrop-filter`) is only on things that float: the top bar, dock, rest pill and sheets. Cards that scroll use tinted glass (`--gl-tint`) instead, because twenty blurred panes re-blurring every frame is what made the phone stutter. Animate only `transform`, `translate`, `scale` and `opacity`; anything else repaints every frame. The week strip moves its thumb with `translate` (outside the lift-up `scale`, so it stays under the finger) and, while dragging, only changes the title, never the chips or blurb, so the strip cannot shift under the finger.
- **Water dial.** The readout's dial is a glass orb (`.orbw`) whose water level is the share of today's sets done (`setWater`); two SVG waves slide across the surface and a few bubbles rise, all on `transform`, paused while the readout is off screen or a sheet is open. A ticked set sloshes it. It turns green when the day is complete.
- **XP and levels.** Worked out from the log every time, like the badges (`dayXP`, `xpTotal`): 10 XP a lifting set, 5 a face set, 50 for a session that counts, 100 more when every lift is done, 40 a PR. Level is `floor(sqrt(xp/60))+1`, with a tier name every five levels (`TIERS`). The level shows as an aqua orb in the streak pill and as a card at the top of Progress; ticking a set floats "+10 XP" from your finger, and going up a level plays the full-screen level-up (`levelUp`). Nothing new is stored; past days are summed once and cached in `XPS.past` (reset on import).
- **Your week.** Full-screen story slides (`Story`, `weekData`, `storySlides`): days done, sets and volume, PRs, the biggest day, level and XP, and what's next. Tap the right side for the next slide and the left for the previous one, hold to pause, swipe sideways to skip and pull down to close. Opened from Progress, and Sunday's hero button is "Your week". On a Monday or Tuesday with nothing ticked yet it shows last week.
- **The welcome.** The first open of each day shows a short splash (an orb, a greeting and today's session) for about a second and a half; tap to skip. A tiny script in the head decides this from `hp.hi` so it never flashes on later opens. Skipped with reduced motion.
- **Small touches.** Pull a sheet down from its top to close it (not workout mode). Cards of a new day slide in from the side you moved to. Tapping empty sky blows a few bubbles (`FX.bubbles`, a soft "bloop" if Sounds is on). The painted sky and hills shift a little with the mouse, or with the tilt when Tilt light is on (`parallax`). On iPhone, which has no vibration API, `buzz` clicks a hidden switch input to get the system haptic tick.
- **Body map.** Progress shows a front and back figure (`bodySVG`, `bodyHTML`) with each muscle lit by the sets ticked on it this week: 1-2, 3-4, 5-7, 8+. A lift's muscle comes from its label in `PLAN` through `MUS`; tap a muscle for its count. The week story has the same map as its third slide.
- **Your own stars.** Every session that counts is drawn into the painted sky as a star (`myStars`, seeded by date so it never moves), a PR day's star is gold, and the days of a streak are joined into a constellation. The sky repaints when today starts or stops counting (`SKY.paint`).
- **Aurora.** Once every lift is ticked today, `html.aurora` fades in three curtains of light behind the hills (`.aur`, transform and opacity only, paused while a sheet is open).
- **Orb colors.** Aqua, then Glacier at level 3, Abyss at 6, Sunlit at 10, Ember at 15 and Aurora at 20 (`SKINS`). Picked in Progress settings and kept in `hp.prefs` as `skin`; the color recolors the dial's water, the level chip and every orb. The level-up moment says when a new one unlocks.
- **Daily quest.** Each lifting day from 2026-11-04 on gets one goal picked from the date (`questOf`): beat last time on one of today's lifts, every set of every lift, a PR on anything, all lifts inside a time limit, or lifts plus the whole face block on face days. Done is checked from the log, so the 75 XP is part of `dayXP` and never double counts.
- **Extras in settings.** Voice coach (speech at ten seconds and at the end of rest, saying what comes next) and Tilt light (the glass highlight follows the phone's tilt; iPhone asks for motion access once). Both are off by default. Workout mode keeps the screen awake where the browser supports it.
- **Share and body weight.** The finish card has Share, which hands a drawn image of the session to the share sheet (or downloads it). Progress has a body weight log in `hp.bw` with a trend line; Export and Import carry it too.
- **Form videos.** `VID` maps each exercise's `form` phrase to a short YouTube video that plays inside the card (muted at first, via youtube-nocookie). A new exercise without an entry falls back to a YouTube search link. To swap a video, change its id in `VID`.

## Spot, the coach in the corner

The orb at the bottom right of the page, and the **Ask Spot** button inside every exercise card. All of it lives in `index.html`, in the script block headed `Spot: the coach in the corner`. It has two brains:

- **On-device.** Answers from the plan itself: `PLAN`, `FACE`, and the Straps and Rules text on the page. Free, instant, works in the basement. Edit the plan and its answers follow, nothing else to update. The only hand-written knowledge is the short glossary (`TECH` and `GLOSS`): myo-reps, rest-pause, ramp sets and so on.
- **Claude.** Real AI for open questions. It needs signal and your own Anthropic API key, pasted into Spot's settings (the sliders icon). With no key, no signal, or any error, Spot answers on-device instead and says why.

The key never goes in this repo. It is stored in that browser's `localStorage` under `hp.spot`, sent only to `api.anthropic.com`, and billed to your Anthropic account, so use a dedicated key with a low spend limit. Each phone or browser needs the key pasted once. Clearing site data, or "Remove key from this device", deletes it.

- The default model is Haiku 5.5 (`DEFAULT_MODEL`, `claude-haiku-5-5`); the settings let you pick Opus 5.5 or Sonnet 5.5 per device, and a pick saved from an older model moves to its successor (`RENAMED`). Any Anthropic API key works for every model. Opus and Sonnet requests opt into the server-side refusal fallback; Haiku 5.5 has none, so it never sends it.
- The whole program is sent as a cached system prompt, built by `prompt()`. Keep it free of dates or anything else that changes between requests, or the cache stops working; per-request context belongs in `nowContext()`.
- Spot's answers are written into the page as escaped text with a tiny markdown subset (`fmt()`). Keep it that way: model output must never reach `innerHTML` unescaped.

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
- Deleted a reminder on purpose? The next run puts it back. Tick it off instead, completed items count as present.
- The reminder script is safe to run from anywhere, any number of times. For each of the next 7 days it looks in the Workout list for an item with that day's exact name and a due date on that day, completed or not, and creates one only if none is there. The log line says how many it created and how many were already in place. Only one copy runs at a time; a run waiting on the permission prompt holds `~/.local/state/workout/reminder.lock` and later runs exit at once.
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

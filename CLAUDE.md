# Working on Chotki

Read this before changing anything. It is the orientation document; `design.md`
holds the reasoning, `checklist.md` the build order, and `context.local.md` the
personal context (gitignored — never commit it, never quote it publicly).

## What this is

A macOS app for keeping an Orthodox prayer rule and honestly measuring whether
it is kept. Menu bar popover **and** a full window with a Dock icon. Written for
Ryan, in daily use by him, published as an alpha at
`github.com/Orthobro83/chotki` for a private community to test.

## Where things are

| | |
|---|---|
| Project and repo | The vault, on an **external drive** — check it is mounted before anything else |
| His live data | `~/Library/Application Support/Chotki/chotki.sqlite` (+ `-wal`, `-shm`) |
| Daily backups | `~/Library/Application Support/Chotki/backups/` |
| Installed app | `/Applications/Chotki.app` |
| Liturgical data | `orthocal.info` — free, no key, the only network call the app makes |

`core/` is a pure SwiftPM package: Foundation and SQLite only. CI builds and
tests it on Linux every push, and a guard job fails the build if it ever
imports AppKit, SwiftUI, UserNotifications or similar.

`macos/` should hold only what is genuinely platform-specific: views, the
notifier, launch at login, the menu bar and window, the timer that drives
reminders, sound playback, icon drawing. **Anything that decides something
belongs in core.** `Practice` answers what is due on a day, whether a day is
settled, whether a rule is paused, and which repairs a loaded record needs.
`ReminderTicker` decides what to show and what to withdraw. If a new type in
`macos/` imports nothing from Apple, it is in the wrong place.

### On porting

Swift runs properly on Windows and Linux, so those ports inherit `core`
unchanged and rewrite only the interface. **Swift does not run on Android in
any practical way** — an Android version means a Kotlin reimplementation.

That makes core more important, not less. Core plus its test suites is the
*specification* a reimplementation is written against: every decision stated
once, with tests that say what it must do. Behaviour left in the platform layer
has to be rediscovered by whoever writes the port, and it is exactly the layer
where every bug found by hand has been.

## Constraints that are not negotiable

These are enforced by tests, not left to judgement. Read the corresponding
sections of `design.md` before touching anything near them.

- **Encouraging, never shaming.** No red, no "failed", no broken-streak
  language, no comparison against a target or a better past self. Pausing
  removes days from the record rather than counting them against anyone. If a
  change would make this feel more like a habit-streak tracker, it is wrong
  however well it tests.
- **The app never congratulates anyone for praying.** Keeping a day is answered
  with thanksgiving — "Glory to God for all things" — not applause.
- **Descriptive, never prescriptive.** The app reports what the church calendar
  marks and names who to ask. It never tells anyone what they must do, and never
  issues dietary instruction.
- **Nothing is enabled by default.** Taking a rule on is always deliberate.
- **Participation is never assumed.** Fasting and feasts are each
  hidden / shown / observed, defaulting to *shown*. People have health
  conditions and no parish within reach; neither is a failure.
- **Text from the calendar is never re-cased.** The app's own labels are
  lowercase by design; orthocal's words are shown as it writes them.

## Building, installing, verifying

```bash
cd macos && swift build          # or ./build-app.sh release
./install.sh                     # builds, installs to /Applications, launches
```

**Always use `install.sh`.** Building into `dist/` and then launching
`/Applications` leaves someone testing yesterday's binary — that has already
happened and cost a whole exchange.

Tests: `swift test` in both `core/` and `macos/`. Around 250 of them. CI runs
core on macOS and Linux, the portability guard, and the macOS suite.

### Looking at the interface

`CHOTKI_RENDER=<prefix>` makes the app draw its own views to PNG offscreen. It
works on a throwaway copy of the database and never reads the screen. Variants:
`CHOTKI_RENDER_LIVE=1` uses the real data untouched; `CHOTKI_EXPORT_ICON=<dir>`
writes the iconset.

**What it cannot do**, and these limits have caused real misses:

- It does not draw `ScrollView` contents. That is why each screen is split into
  `XView` (scroll chrome) and `XViewContent`.
- It does not draw AppKit-backed controls — pickers and toggles render as
  placeholders.
- **It is not the live app.** It proves layout and copy. It cannot prove
  clicking, typing, notifications, or that a view is reachable at all.

## Mistakes already made here — do not repeat them

- **Verified a hand-composed view instead of the real one.** Rendering
  `ZStack { Backdrop; Content }` proved the marks drew, and said nothing about
  whether any screen used them. The window had none. Render the *actual* view.
- **Two surfaces, one fix.** The popover and the window are different view
  trees. A change to one is not a change to both — the navigation buttons and
  the marks were each dead in the window while working in the popover.
- **Tests wrote to his real machine** twice: preference files in
  `~/Library/Preferences`, and an empty backup into Application Support.
  Anything a test constructs must be told not to touch the world.
- **A screenshot nearly carried his private data** into a public README. The
  render harness now copies only the liturgical cache.
- **Never screen-capture his display.** It caught a private messaging window
  once. Use the render harness.
- **Python edits that do not assert fail silently.** Several patches quietly
  no-oped and looked successful. Always `assert old in s`.
- **Never mask build output.** `>/dev/null` hid a failing build and shipped a
  stale bundle.
- **The database is WAL mode.** A file-level copy must include `-wal` and
  `-shm` or it silently loses recent data.

## State as of 21 August 2026

Alpha published: `v0.1.0-alpha`, Apple Silicon only, ad-hoc signed, marked
prerelease. All seven build phases complete.

Outstanding, in rough priority:

1. **A universal binary.** Needs Xcode, which is not installed — Command Line
   Tools cannot cross-compile. Testers on Intel Macs cannot run it at all, and
   "it will not open" reads identically whether the cause is the architecture or
   Gatekeeper.
2. **Notarisation**, or every tester must go through System Settings › Privacy
   and Security. Needs the Apple Developer Program at $99/yr — his call.
3. **A priest's review** of the glossary and the patristic attributions. He has
   said this will happen before the app goes further.
4. **Confirming the reckoning** with his parish. Julian is the default and ROCOR
   is Julian, so this is confirmation rather than a blocker.

Every bug found so far came from him using the app, never from the tests, and
every one was in the interface layer rather than core. Expect that to continue.

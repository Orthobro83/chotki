# Working on Chotki

Read this before changing anything. It is the orientation document; `design.md`
holds the reasoning, `checklist.md` the build order, and `context.local.md` the
personal context (gitignored — never commit it, never quote it publicly).

`retrospective.md` is the other one to read first: what went wrong building the
macOS app, which assumptions caused it, and the working rules that came out of
it. The section below on mistakes is the short version; the retrospective says
why they happened. `android/` holds the port plan and the specification the
Kotlin reimplementation is written against.

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

Two exceptions, deliberate: `ReminderDriver` (a `Timer` on a run loop) and
`SettingsStorage` (the Application Support path and the old `UserDefaults`
migration). Both import only Foundation, but both are platform glue rather
than decisions — what they used to decide now lives in `ReminderTicker` and
the `Store` — so do not move them.

### On porting

Swift runs properly on Windows and Linux, so those ports inherit `core`
unchanged and rewrite only the interface. **Swift does not run on Android in
any practical way** — an Android version means a Kotlin reimplementation.

That makes core more important, not less. Core plus its test suites is the
*specification* a reimplementation is written against — inventoried, with the
parity gate, in `android/PARITY.md`, and sequenced in `android/PORT.md`: every decision stated
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

**Reach for `CHOTKI_RENDER_WINDOW=<prefix>` first.** It puts the real
`MainWindowView`, and then the real `RootView` at popover size, into an
off-screen `NSWindow` and asks the view hierarchy to draw itself. Because that
goes through AppKit rather than `ImageRenderer`, it draws **ScrollView contents
and real AppKit controls** — which is most of this app. It also prints the items
of every pop-up menu it finds (`menu: ...`), the one thing no screenshot can
show. It draws the view; it never reads the display.

`CHOTKI_RENDER=<prefix>` is the older path: `ImageRenderer` on content views in
isolation. Still useful for a single view in a known state, but it draws every
scrolled screen as an empty panel, which is how a missing feature once got
signed off here. `CHOTKI_RENDER_LIVE=1` uses the real data untouched;
`CHOTKI_EXPORT_ICON=<dir>` writes the iconset.

**What neither can do:**

- `ImageRenderer` (`CHOTKI_RENDER`) draws no `ScrollView` contents and no AppKit
  controls. That is why each screen is split into `XView` (scroll chrome) and
  `XViewContent`.
- **Neither is the live app.** They prove layout and copy. They cannot prove
  clicking, typing, notifications, or that a view is reachable at all. An
  animation or a `ScrollViewReader` scroll may simply not appear — if it does
  not, that is not evidence either way, so do not ship it on the strength of a
  render.

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
- **A new file in `core/` is invisible to the `macos/` build.** SwiftPM caches
  the dependency's source list, so the build compiles ChotkiCore *without* the
  new file and reports `cannot find 'X' in scope` for a public type that is
  plainly there. `swift package --package-path macos clean` fixes it; touching
  `Package.swift` does not.
- **The database is WAL mode.** A file-level copy must include `-wal` and
  `-shm` or it silently loses recent data.

## State as of 26 August 2026

Three platforms, all in daily testing by Ryan.

| | |
|---|---|
| macOS | universal (arm64 + x86_64), ad-hoc signed, `v0.1.0-alpha` published |
| Android | `v0.1.8-alpha` published, prerelease, signed with his own key |
| iOS | on his iPhone 13 by free provisioning, seven days at a time |

**Published is not delivered.** Father Moses and Maximos are the only intended
eyes on the alpha and Ryan hands it to them himself. As of 26 August neither had
received any build. Never write that a named person has one.

Outstanding, in rough priority:

1. **Notarisation**, or every macOS tester must go through System Settings ›
   Privacy and Security, and iOS cannot reach TestFlight at all. Needs the Apple
   Developer Program at $99/yr — his call, and now the single biggest blocker to
   anyone else running the iOS build.
2. **A priest's review** of the glossary and the patristic attributions. He has
   said this will happen before the app goes further.
3. **Landscape, before any public release.** Asked for on 26 August: the phones
   are portrait-locked, and the landscape layout for a phone or a tablet should
   be *the macOS layout* rather than a third design. macOS is already the wide
   arrangement — sidebar, calendar and the day side by side — so this is
   choosing between two existing layouts on width, not drawing a new one.
   Nothing about it is started.
4. **Confirming the reckoning** with his parish. Julian is the default and ROCOR
   is Julian, so this is confirmation rather than a blocker.
5. **A Linux port**, if wanted. Core runs there already; see the note below.

Done since, and no longer outstanding:

- **The universal binary.** `swift build --arch arm64 --arch x86_64` works with
  Xcode installed; it took one line in `build-app.sh`. Release builds are
  universal, debug builds stay single-arch, and CI fails if a release bundle
  loses a slice.

### What a Linux port would actually cost

`core/` runs on Linux today — CI builds and tests it there every push, and
`HTTPFetching` already imports `FoundationNetworking` conditionally. Every seam
a platform has to fill is a named protocol: `Notifier`, `LaunchAtLogin`,
`Store`, `Clock`, `HTTPFetching`. The bell and the tick are *synthesised* in
core (`Sound/BellTone.swift`); only playback is platform.

So the port is not the app. **The port is the views, and SwiftUI does not exist
on Linux** — all ~4,000 lines of it would be rewritten against GTK or similar,
the way Android's Kotlin reimplementation was. iOS is the better guide to size
than macOS: the same screens came to 2,800 lines there once the platform
wiring was excluded.

Skipping the tray is right and removes the worst of it: `checklist.md` already
records that GNOME needs a shell extension for any tray app at all, which no
stack choice fixes. A plain windowed app runs the same on GNOME, KDE and XFCE,
because GTK is a library rather than a desktop dependency.

## Adding a prayer, a reading or any other text

New text brings its glossary with it. A word a newcomer would stop at needs an
entry; "so" does not, "Theotokos" does. `GlossaryCoverageTests` enforces it
mechanically — it scans everything bundled and fails on a term of art the
glossary cannot explain.

Spotting the gap is mechanical. **Writing the definition is not mine to do**:
what an entry should say about a religious term goes to Ryan or a priest. Put
the term in `awaitingAnEntry` and in `checklist.md`, which the same suite keeps
in step, so the debt is visible rather than buried in a test file.

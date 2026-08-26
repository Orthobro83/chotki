# Porting Chotki to iOS

Read `../retrospective.md` and `../android/PORT.md` first. The Android port is
where the expensive lessons were bought, and most of them apply here even
though the work is a different shape.

## This is not the Android port

Android needed a Kotlin reimplementation, and that reimplementation is where
every parity bug came from: the clock setting, the reminder controls, the church
and calendar pickers, the whole first-run screen. Each existed on the Mac and
simply never crossed, and none of them could be found by running the app,
because a control that was never written has nothing to click.

iOS has none of that problem. `core` imports Foundation and SQLite and nothing
else, so **iOS inherits it unchanged** — the same file, the same tests, the same
decisions. Nothing to translate means nothing to translate wrongly.

What is left is the interface, and even there:

| | |
|---|---|
| Pure SwiftUI on macOS today | 20 files — port with changes, not rewrites |
| AppKit-bound | 9 files — need iOS equivalents |

The nine: `ChotkiApp`, `MainWindow`, `MainMenu`, `ReportWindow`, `RenderMode`
(the offscreen render harness), `SettingsView` (AppKit pickers), `CrossIcon` and
`ChotkiMarks` (NSBezierPath drawing), `IconExport`.

So the risk here is not "did it cross" — it is that a screen ports *visually*
and stops behaving, which is the failure this project keeps meeting from the
other direction.

## What still applies from Android

1. **Verify interaction, not appearance.** Every interface bug in this project
   has been a control that drew correctly and did nothing. A screenshot showed
   none of them.
2. **A fix goes everywhere the problem is.** There will be three platforms now.
3. **The feature surfaces must match, mechanically.** `PortParityTests` holds
   macOS and Android against each other; iOS joins it. It names the type a
   control must reach for, not the field, because searching for a field name is
   what let `reminders` through — the word was present, in a line of copy.
4. **Anything the platform enforces at a version boundary will be invisible
   until it is not.** On Android that was edge to edge at API 35. On iOS the
   equivalents are safe areas, Dynamic Type and the notch.

## What is genuinely easier

**Reminders.** The hardest part of Android — Doze, Samsung's sleeping-apps
list, exact-alarm permissions, alarms that had to be written down to be
cancellable — mostly does not exist here. `UNUserNotificationCenter` schedules a
local notification and the system delivers it whatever the app is doing.

That does *not* mean the reminder logic is untested ground: `Scheduler` and
`ReminderTicker` are core and already carry every decision. What changes is only
the last mile, and the last mile is where all five Android reminder bugs lived.
Withdrawal in particular — `ReminderTicker` decides what to show *and what to
take down*, and Android never used it. iOS should, from the first commit.

## The motion

Asked for explicitly: the Android app switches screens plainly and this should
glide. iOS gives that nearly free, and the point is to use its own idioms rather
than invent animation.

- `NavigationStack` for the day → prayers → editor depth, with the system push
  and the interactive back-swipe. That swipe is also the answer to the Android
  back-button trouble, which took three rounds to get right.
- Sheets with detents for the Library and the rule editor — a half-height sheet
  that can be dragged full, rather than a screen replacing a screen.
- `matchedGeometryEffect` where a thing genuinely persists across a transition:
  a rule row opening into its prayers, a day in the month grid becoming the
  day's header.
- Spring animation on state that changes under the finger — the rope's count,
  a rule ticking over.
- `.scrollTransition` for the month grid folding to a week, which on Android is
  a hard swap.

**One constraint this must not cross.** The app never congratulates anyone for
praying, and a kept day is answered with thanksgiving, not applause. So: glide,
never celebrate. No confetti, no bounce on completion, no flourish that reads as
a reward. Motion here is for continuity — showing that a thing came from
somewhere — not for reinforcement. If an animation would feel at home in a
habit-streak app, it is wrong however well it moves.

## What phase 2 settled

The store opens in the iOS sandbox, the ladder runs, and the record survives a
relaunch. Three things worth having in writing:

- **WAL works.** Swift's `PRAGMA journal_mode=WAL` is accepted on iOS, where on
  Android the equivalent threw and took every store operation with it. After one
  rule the main file was 4KB and the write-ahead log 144KB, so anything copying
  the database must take `-wal` and `-shm` with it — the same warning as macOS,
  and it bites harder here because iOS backup is file-level.
- **iOS and macOS share a database format.** Both are Swift, both write the same
  encoding, so a record could in principle move between them. Android's cannot,
  and that asymmetry is worth remembering before anyone promises a backup is
  portable.
- **Schema versions are per-platform from 7 onward.** Swift stops at 6; Kotlin's
  7th step is its own. Only the table shape is shared.

## What phase 4 settled

**Five tabs, not Android's six.** iPhone folds a sixth into a "More" list,
which is a worse home for anything than a considered omission. The glossary is
the one left out: it is reached by tapping a word that puzzled you, which is how
anyone actually arrives there, and from Settings for browsing. macOS makes a
third choice — three tabs. So the arrangement is per-platform; **the capability
is not**, and `PortParityTests` is what keeps that true.

**A stack per tab.** Going three deep into a rule's prayers and then to the
readings does not lose where you were, and coming back finds it. Verified by
doing it rather than by reading the documentation.

**Routes are values.** Android held navigation as "which screen is showing" and
the back button guessed; it took three rounds before back went back one
reliably. A `NavigationPath` of enum cases cannot guess, and the interactive
back-swipe comes with it for nothing.

**The zoom is guarded.** `navigationTransition(.zoom)` arrived in iOS 18 and the
floor here is 17, so below that the push is the ordinary one. A transition is
not worth excluding a device over.

## Phases

Each ends with something runnable and tested, as the Android phases did.

1. **The project builds.** An iOS app target depending on `core`, launching to a
   blank screen in the Simulator. Proves the package graph and nothing else.
2. **The store on a device.** `SQLiteStore` against the iOS sandbox, schema
   ladder included. Android's equivalent found that `execSQL` refuses PRAGMA;
   assume something similar waits here.
3. **The day.** Month grid, the day's rules, ticking one. First real interaction.
4. **Navigation and motion.** `NavigationStack`, sheets, the transitions above.
   Done before more screens, so the rest are built into it rather than retro-fitted.
5. **The rest of the screens.** Prayers, rope, reading, psalter, progress,
   glossary, settings, the welcome.
6. **Reminders.** `UNUserNotificationCenter`, driven by `ReminderTicker` —
   including withdrawal, which Android still does by hand.
7. **Parity.** iOS joins `PortParityTests`. Nothing ships until it passes.
8. **On the phone.** The 7-day free-provisioning limit makes the Simulator the
   daily loop; the phone is for what the Simulator cannot say.

## Before any of it

`sudo xcode-select -s /Applications/Xcode.app`, and an iOS Simulator runtime,
which downloads separately from the SDK.

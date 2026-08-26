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

## What phase 6 settled

Reminders on iOS are a different shape, and a simpler one. On Android a reminder
is an alarm that wakes the app so it can post a notification, and the alarms had
to be written down because AlarmManager will not say what it is holding — all
five reminder bugs lived in that gap. Here the notification *is* the schedule:
handed to the system with an identifier and a time, delivered whatever the app
is doing, and taken back by the same identifier.

So the problem reduces to keeping one set in step with another, and that
arithmetic is separated from the system deliberately. A test that drives the
real notification centre needs authorisation and a dialogue, and the temptation
is then to test the app's own note of what it did instead — which is what the
first Android version of this did, and it passed with the fix removed. The
reconciliation is a pure function, tested directly, and the withdrawal test was
run against the code with the withdrawal taken out and watched to fail.

**Withdrawal is in from the first commit.** `ReminderTicker` decides what to
show *and what to take down*; Android has it ported, tested, and used by
nothing.

Sound uses `.ambient` with `mixWithOthers`, which follows the media volume. The
Android equivalent used sonification, which follows the ringer — so a phone on
vibrate played nothing, which is most phones most of the time, and it worked on
an emulator and not on a real device.

## What the first hour on the phone settled

Seven faults, and the useful split is which kind each was.

**Three were the port gap this project already knows about**, and all three
were greppable with no phone in the room: the prayers screen offered the rope
prayers and neither the rules nor the read-only prayers, showed no prayer text
at all, and had its own copy of core's `PrayerScreen` — so the rope never
followed the prayer and the count died on every navigation.

**One was new: a reader with no writer.** The reading screen read the calendar
cache and nothing on the platform ever wrote to it. That does not look like a
missing feature; it looks like a slow network, and it says so in its own words.
`PortParityTests` now asks that any tree containing `liturgicalDay` also
contains `LiturgicalService` and a refresh.

**Three were ordinary interface bugs**: no app icon (the asset catalog had no
`AppIcon`), the reading column sized to its content instead of the width, and
the library was named in the empty-day text while only being reachable from a
small corner button.

Two things followed that are worth keeping:

- **The rope toggle went to the toolbar, not the footer.** macOS keeps it at the
  foot of a fixed-height popover. Here the morning prayers are eleven prayers
  long, and a control you have to read a whole rule to reach is one nobody
  finds. Same capability, different placement — which is the same call the tab
  count already makes.
- **Glossary links are per-tab.** macOS calls a method on one model because it
  has one window. Each tab here owns its `NavigationPath`, so `OpenTerm` goes
  through the environment and a word tapped in the Reading pushes onto the
  Reading's stack. The back-swipe returns to the passage it was read in.

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

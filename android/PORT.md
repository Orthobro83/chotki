# Porting Chotki to Android

The order below is not arbitrary. Each phase is verifiable on its own, depends
only on what came before it, and ends with something that can be demonstrated
rather than asserted. `PARITY.md` is the specification; `../retrospective.md` is
why some of these steps look paranoid.

**The shape of the whole thing:** translate `core/` into a pure Kotlin module,
prove it with a translation of its 280 tests, and only then write an interface
on top. The macOS app took the opposite route — interface first, decisions
scattered, extracted later — and paid for it in a week of interaction bugs.

---

## Phase 0 — Decide, before any code

Half an hour with Ryan. These change everything downstream and are cheap now,
expensive later. Open questions are listed at the end of `README.md`.

Settle: feature scope for v1, minimum Android version, which device it must run
on, whether the database should be interchangeable with the macOS one, how the
alpha reaches the Brotherhood, and whether shared content moves to JSON.

**Done when:** the answers are written into `README.md` and this file's
assumptions are either confirmed or corrected.

## Phase 1 — Scaffolding and the guard

Gradle project, two modules: `:core` (pure Kotlin/JVM, **no Android
dependencies**) and `:app` (Android, Compose). CI on every push: build both, run
`:core` tests, and **fail the build if `:core` imports anything from `android.*`
or `androidx.*`**.

That guard job is the single most valuable thing in the macOS repo and it goes
in on day one this time, not day three.

**Done when:** CI is green, and a deliberate `import android.os.Build` in
`:core` turns it red.

## Phase 2 — `CalendarDate` and time

Everything stands on this. It is a timezone-free civil date with O(1)
arithmetic over `daysSinceEpoch`, and it deliberately depends on no date library
at all — which means it translates to Kotlin with no `java.time`, no
`kotlinx-datetime`, and no behaviour differences to chase.

Port `TimeOfDay`, `Weekday`, `Clock` with it. Translate all 14 `CalendarDate`
tests including the DST and leap-day cases.

**Done when:** the date tests pass, and the DST test — the one asserting a
nonexistent local time returns null rather than a guess — passes for the same
reason it does in Swift.

## Phase 3 — The model and recurrence

`Rule`, `Activation`, `Occurrence`, `Recurrence`, `RecurrenceEngine`,
`EditPlanner`, `RecurrenceForm`. This is where the three-way edit lives — edit
this occurrence, this and future, or all — and it has 28 tests across three
files because it is the part most able to lose someone's history quietly.

**Done when:** `RecurrenceTests`, `EditPlannerTests` and `RecurrenceFormTests`
are translated and green.

## Phase 4 — The store

Same schema, same five-step migration ladder, same WAL mode. SQLDelight or raw
`androidx.sqlite` — not Room, which wants to own a schema this one already has.

Carry across the legacy-database fixture: a test that opens a version-1 database
and migrates it forward. It caught two broken migrations on macOS, both written
by someone (me) who reversed only the newest change.

**Done when:** `StoreTests` and the migration tests pass, and an actual macOS
`chotki.sqlite` opens correctly on Android — which also answers the
interchangeability question empirically.

## Phase 5 — Practice and progress

`Practice` (what is due on a day, whether a day is settled, whether a rule is
paused), `ScoringEngine`, `ProgressReport`, `Prose`.

This is where the tone constraints are enforced by test: progress stops at
yesterday, pausing is never punished, no streak language. Those tests are not
optional and not stylistic — they are the reason Ryan uses the app.

**Done when:** `PracticeTests` and `ScoringTests` pass, including the ones
asserting what the app must *not* say.

## Phase 6 — Liturgical

`OrthocalClient` against `orthocal.info`, the day cache, `Jurisdiction`,
`Tradition`, `Observance`, `ObservanceSettings`, `FastingSeason`. The client
goes behind the same `HTTPFetching` interface so tests stay offline.

Watch the reckoning trap: the URL takes a **civil** date, the response returns
the date in the requested reckoning, and Julian is thirteen days off. It is
tested; keep the test.

**Done when:** `LiturgicalTests`, `ObservanceTests` and `TraditionTests` pass
against recorded fixtures, and one live call returns a plausible day.

## Phase 7 — Reminders

`Scheduler`, `ReminderPolicy`, `RuleReminders`, `QuietHours`, `ReminderTicker`.
All of it is decisions, all of it belongs in `:core`, and none of it touches
Android yet.

`ReminderTicker` in particular is pure: given the time and what has fired, what
should be shown and what withdrawn. Keep it that way — the equivalent logic on
macOS was in the platform layer at first and that is where the bugs were.

**Done when:** `SchedulerTests`, `ReminderSettingsTests`, `QuietHoursTests` and
`ReminderTickerTests` pass.

## Phase 8 — Content

Glossary (~110 entries), prayers (18 + 4 sequences), rule library, patristic
readings, prayer sources.

**Move it mechanically.** Script the translation from the Swift sources, or take
the JSON route if Phase 0 chose it. Do not hand-copy prayer text: a
transcription error in the Trisagion is not a typo. Verify by comparing ids and
counts between platforms, not by reading.

**Done when:** ids and counts match Swift exactly, the glossary's cross
references all resolve, and the prayer-scanning tests pass.

## Phase 9 — The Android platform layer

Now, and not before: notifications and channels, `AlarmManager` for timed
reminders (exact alarms need permission from Android 12), `WorkManager` for the
daily liturgical fetch and backups, storage paths, a boot receiver so reminders
survive a restart, and tone synthesis for the prayer-rope chime (the `WAV` and
`ToneRenderer` code is portable and already tested).

There is no `LaunchAtLogin` equivalent; Android has no login items.

**Done when:** a reminder fires on a real device, survives a reboot, and
respects quiet hours.

## Phase 10 — The interface

Compose, Material 3, dark. Screens, in the order they earn their place: Rule
(calendar, the day, the library beneath it), Prayers, Reading, Progress,
Glossary, Settings, Onboarding.

**Verify by driving it, not by looking at it.** Compose UI tests for anything
that can be tapped. Every macOS interface bug in this project was a control that
drew correctly and did nothing, and a screenshot showed none of them.

**Done when:** each screen is reachable, each control does what it claims, and
there is a test asserting no screen is orphaned — the macOS `WindowRoute` test
has caught two.

## Phase 11 — On the device, then to the Brotherhood

Ryan's own device first, with his real rule, for several days. Then an APK for
the Brotherhood with the same alpha framing as the macOS release, and the same
licence terms.

**Done when:** Ryan has kept his rule on Android for a week without opening the
Mac app to check something.

---

## Guard rails, carried over

1. **Verify interaction, not appearance.** Drive it, or say you did not.
2. **The portability guard goes in first**, and is mechanical.
3. **Never hand-copy liturgical text.**
4. **Ask for a reference** on anything religious. Do not infer it.
5. **Practice questions go to Ryan or a priest**, stated as questions.
6. **No test may touch a real device's storage.**
7. **Say what you could not check**, every time.

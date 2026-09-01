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

### Proving a translation, rather than believing it

Phase 2 established the technique the rest of the port should use. The Swift core
and the Kotlin one are on the same machine, so agreement between them can be
*measured*:

1. A throwaway Swift test emits a fixture — inputs and what the specification
   answers for each.
2. The fixture is committed under `android/core/src/test/resources/`.
3. A Kotlin test reads it and asserts the port agrees, case for case.

`date-parity.tsv` is the first: 1,985 dates from 1900 to 2100, with the ISO form
and weekday Foundation computed for each. It exists because the Kotlin
`CalendarDate` is deliberately *not* a line-by-line translation — it replaces two
Foundation calls with arithmetic, which is a better design and a fresh chance to
be subtly wrong.

Worth doing wherever the answer is a value rather than a behaviour: recurrence
expansion over a year, scoring over a generated history, the glossary's term
scan. Not worth it where the Swift test already states the rule plainly enough
to translate.

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

### Phase 8a — Making reminders actually arrive

Its own step because it is the most likely thing to fail silently on a real
phone, and because three separate systems have to say yes before a reminder
appears at all:

1. **`POST_NOTIFICATIONS`** — a runtime permission from Android 13. Refused or
   never asked, nothing appears and nothing errors.
2. **Exact alarms** — permission from Android 12. Without it a reminder for a
   rule kept at 06:30 arrives whenever the system finds convenient.
3. **Battery optimisation** — Doze will defer an unexempted app's alarms, and
   Samsung's OneUI goes further with its own sleeping-apps list on top.

So: a first-run screen that asks for all three, in plain language, saying what
each is for. `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` puts the exemption
one tap away; `PowerManager.isIgnoringBatteryOptimizations` reads back whether
it took.

**Two things that cannot be done for the user.** Samsung's "sleeping apps" list
is separate from the standard exemption and cannot be set or even read
programmatically — being exempt from Doze does not remove an app from it. On a
Samsung build (`Build.MANUFACTURER`) the screen has to show the route by hand:
Settings → Battery → Background usage limits → Never sleeping apps.

**And a standing diagnostic in Settings**, not just a first-run wizard: which of
the three are granted, which are not, and what to do about each. Permissions get
revoked, phones get replaced, and OEM updates reset these lists. An app whose
whole point is honest measurement should be able to say plainly whether its
reminders are actually going to arrive — and should say so rather than quietly
not firing.

Asked once, plainly, and skippable. Never nagged: a wall of permission dialogues
on first run is exactly the tone this app does not take.

**One caveat for later.** Google Play restricts
`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` to apps with a qualifying use case. It
does not apply to a direct APK, but it would need answering if the Play Store
ever comes up. The fallback that is always permitted is
`ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`, which opens the list and lets the
user find the app themselves.

**Done when:** the diagnostic reports all three states correctly on the
emulator, and a reminder fires on time across a reboot.

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

## Testing across Android versions

Two endpoints do not cover the middle. The bottom bar drawing under the gesture
pill arrived at API 35 and was broken on 35, 36 and 37; the API 33 device this
was built against showed nothing, and it was found only because a newer
emulator happened to be running.

So the build now creates its own emulators, one per gate — the levels where
Android changed something this app relies on, not a sample:

| | |
|---|---|
| 31 | exact alarms became a permission; PendingIntent mutability required |
| 33 | notifications became a runtime permission |
| 34 | exact alarms tightened further |
| 35 | edge to edge enforced for apps targeting 35+; this app targets 37 |
| 36 | predictive back by default; orientation lock ignored on large screens |
| 36, tablet | the large screen that ignores the portrait lock |

```bash
cd android && ./gradlew :app:gatesGroupDebugAndroidTest   # all of them
cd android && ./gradlew :app:api35DebugAndroidTest        # one
```

Each downloads a system image the first time — gigabytes, and minutes per
device — so it is not part of the ordinary build. `.github/workflows/gates.yml`
runs them on a tag or on request, one job per level so a failure at 35 does not
hide 36.

**API 37 is not in the group.** It ships only as beta 16KB-page images, which
the managed-device sources cannot name. Run it against a local emulator.

**None of this replaces the phone.** Samsung's sleeping-apps list, OneUI's
battery handling, real Doze across days — no emulator at any API level has
them.

## Phase 11 — On the device, then to the Brotherhood

Ryan's own device first, with his real rule, for several days. Then an APK for
the Brotherhood with the same alpha framing as the macOS release, and the same
licence terms.

Ready for the device: the release build type signs from a gitignored
`keystore.properties` and shouts if it falls back to the debug key
(`RELEASE.md`); Settings carries the version, the alpha notice, the Brotherhood
disclaimer and the licence, because an apk is passed hand to hand with no
releases page attached; the README says how to sideload it **without developer
mode or USB debugging**, which was the thing standing between this app and
Ryan's daily-driver phone; and `DEVICE-CHECKLIST.md` is the week itself.

Two things surfaced while getting there and were fixed rather than noted:

- **The stored recurrence held Kotlin class names.** kotlinx wrote
  `org.chotki.core.Recurrence.Daily` into the column, so renaming or moving the
  class would have silently failed to decode every rule anyone had taken up.
  The eight names are frozen with `@SerialName` and V7 rewrites what exists.
  This had to happen before an apk went out, not after.
- **There was no way to keep a record.** macOS exports and merge-restores JSON;
  Android had neither, and turns Android's own backup off deliberately. A
  tester changing phones would have lost everything. Settings now saves and
  restores through the Storage Access Framework — no storage permission, the
  person chooses where it goes, and a Mac backup is refused with a reason
  rather than half-read.

**Done when:** Ryan has kept his rule on Android for a week without opening the
Mac app to check something.

---

## Guard rails, carried over

1. **A port is finished when the feature surfaces match, not when it runs.**
   Running the port cannot reveal a control that was never written — there is
   nothing to click and nothing to fail. The clock setting and the whole
   reminders section existed on macOS and never crossed; reminders could not be
   configured at all, so the phone testing the port could not test what the
   port was for. `PortParityTests` holds the two interfaces against each other
   and names the type a control must reach for, not the field — searching for
   the field name is what let it through, because the word `reminders` was
   present in a line of copy above no controls.
1. **Verify interaction, not appearance.** Drive it, or say you did not.
1. **Anything Compose cannot observe must be announced.** The church calendar
   lives in a plain map inside `LiturgicalService`, because the recurrence
   engine asks about forty-two days on every redraw and cannot suspend. Compose
   therefore cannot see it change, and a screen reading it drew once with
   nothing and never again. The counter that announces it is read inside
   `AppState.practice` and `AppState.liturgicalDay`, on every screen's behalf —
   not in the screens, where the next one written would forget.
2. **The portability guard goes in first**, and is mechanical.
3. **Never hand-copy liturgical text.**
4. **Ask for a reference** on anything religious. Do not infer it.
5. **Practice questions go to Ryan or a priest**, stated as questions.
6. **No test may touch a real device's storage.**
7. **Say what you could not check**, every time.
8. **A fix goes everywhere the problem is**, not only where it was reported.
   Labels and headings in Compose take their capitalisation from the shared
   content, which is already correct — do not lower-case them in the view, which
   is how the macOS app acquired the habit in six separate places.

## Reflections — what iOS did, and what Android must do differently

Added to macOS and iOS on 1 September 2026. `reflections-decisions.md` at the
repo root is the specification; this section is the delta list, written while
the iOS version was built so that none of it has to be rediscovered.

### What comes free, and what does not

iOS took about two hours because it **shares `core` unchanged** — `Reflection`,
`ReflectionQuestion`, `ReflectionEntry`, `ReflectionPeriod`, `ReflectionSeries`,
`ReflectionJournal`, `ReflectionArchive`, `ReflectionImport`, the seven prompts
and the four `Store` methods were already there and already passing. Only the
view was written.

**Android gets none of that.** Before a single screen exists:

| To translate | Where |
|---|---|
| `Reflection`, `ReflectionQuestion`, `ReflectionEntry` | `core/.../Reflections/Reflection.swift` |
| The seven prompts, verbatim | `ReflectionContent.swift` |
| `ReflectionPeriod`, `ReflectionSeries`, `ReflectionJournal` | `ReflectionJournal.swift` |
| `ReflectionArchive`, `ReflectionImport` | `ReflectionArchive.swift` |
| Four `Store` methods + `seedReflections` and the export/import extensions | `Store.swift` |
| Schema 7 — `reflection`, `reflection_entry` | `SQLiteStore.swift`, and `Schema.kt` here stops at 6 |
| ~50 tests | `ReflectionTests.swift`, `ReflectionStoreTests.swift` |

`RuleReference` gains a `.reflections` case and `reflectionRuleTitle`, both in
`core/.../Model/RuleReference.swift`. The library rule and the glossary entry
arrive free — both are in the generated JSON under
`android/core/src/main/resources/content/`, already regenerated.

### The three that will bite

**1. The snapshot rule is not a join.** Every `ReflectionEntry` stores its own
copy of the question — `q_title`, `q_notice`, `q_task` — rather than a foreign
key to `reflection`. Translating it as a join looks tidier and is wrong: editing
a question would silently rewrite what every past answer was answering, and the
bug would not show until someone edited one. The columns are deliberate.

**2. An answer is immutable.** Every field of `ReflectionEntry` is `let` in
Swift. Kotlin's `val` in a `data class` gives the same thing — do not reach for
`var` because a builder is convenient. "Locks on save" is structural, not a
rule the interface remembers.

**3. `weekday` is the primary key of `reflection`.** There is exactly one per
day and there always will be. No id column, no ordering, no archived state.

### The interface, and what iOS chose

macOS and iOS disagree in three places, each for a reason that applies to
Android as well:

- **Reading past entries.** macOS uses a panel with ◀ ▶ either side. There is no
  room for chevrons beside a full-width sheet on a phone, so **iOS uses a dated
  list you tap into** — a date with a two-line excerpt, opening on the question
  as it stood plus the answer. Android should do the same; a phone is a phone.
- **Where it lives.** macOS has a sidebar entry. iOS caps at five tabs before
  the system folds the rest into "More", so Reflections is a *route* reached
  from the rule row that names it and from Settings — the same arrangement the
  glossary and Psalter already use. **Android has six navigation items**, so it
  may be able to afford a destination; decide against the existing arrangement
  rather than copying either.
- **The explainer.** A panel that animates down over the top on macOS; on iOS a
  card at the head of the scroll, raised from the toolbar's help mark.

### Behaviour to match exactly

- **Tapping the way through from a rule scrolls to that weekday.** Tapping it on
  a Tuesday lands on Tuesday's question, not at the top of a seven-day scroll.
  Both platforms carry the weekday in the navigation value — `Route.reflections(weekday:)`
  on iOS, `Screen.reflections(weekday:)` on macOS. In Compose this is
  `LazyColumn` + `scrollToItem`.
- **The scroll must be deferred one frame.** A lazy list has not built the later
  days when the screen first appears, so scrolling to Saturday in the same pass
  finds nothing. iOS wraps it in `DispatchQueue.main.async`; Compose wants a
  `LaunchedEffect`.
- **Save asks for confirmation**, because it is irreversible. There is **no
  standing warning** under the field — a permanent notice beside every empty box
  is a nag, and the tone rules rule it out.
- **Neither half of the question is labelled.** The task lines say "At the end of
  the day…" themselves, and a "Notice" label only named what the section is
  already called. Told apart by weight.
- **Import merges and never replaces.** `ReflectionJournal.merge` decides it;
  the interface only reports the counts.
- **A failed write still repaints.** The entry is in memory and valid; swallowing
  the redraw makes a successful save look like a dead button.

### The keyboard

The thing Ryan flagged, and it is handled — but not by hand. SwiftUI lifts a
focused field clear of the keyboard on its own, and it was **checked on the last
day of the seven**, which is the worst case: nothing below it to scroll into.
Verified in the Simulator with the software keyboard actually up, not reasoned
about.

**Android has to do this deliberately.** `android:windowSoftInputMode="adjustResize"`
on the activity, and `Modifier.imePadding()` on the scrolling container. Then
check it on the last day, not the first — the first day always looks fine.

iOS also got `.scrollDismissesKeyboard(.interactively)`, because seven text
fields with no way to put the keyboard away except by saving is unpleasant.
Compose's equivalent is a `nestedScroll` connection that clears focus.

### The typeface

macOS now sets everything meant to be **read** in Iowan Old Style, and keeps the
system sans for everything meant to be **operated** — the sidebar, the month
grid's numerals, times, buttons and settings. That division is the thing to
port, more than any particular file.

**Each platform picks the native face closest to what macOS chose.** The look
should be recognisably the same app; matching the exact file is neither possible
nor the point.

Android cannot have Iowan Old Style at all: it is John Downer's, released through
Bitstream and licensed to Apple, and **redistributing it would be a licence
violation**. So:

- **Reading face: Charter**, bundled. This is not a consolation prize. Charter is
  Matthew Carter, 1987, also originally Bitstream, drawn to the same brief as
  Iowan — large x-height, low stroke contrast, sturdy blunt serifs, engineered to
  hold up at text sizes. It is already the second face in the macOS chain, so a
  Mac without Iowan and an Android phone read the same. Bitstream released
  Charter permissively; **XCharter** is the maintained extension and is the one
  to ship. If bundling is refused for any reason, `Literata` and `Source Serif 4`
  are the next nearest, both OFL.
- **Chrome: Roboto**, the platform sans, untouched. It plays the part SF plays on
  macOS, and swapping it for anything else would make the app look foreign on the
  device rather than consistent with itself.

One trap worth knowing when translating: on Apple platforms `Font.custom` falls
back **silently** when a face is missing. The app asked for `Cardo` in six places
for months and Cardo was never installed or bundled, so all six had quietly been
rendering in the system sans, and nothing looked broken. A bundled font on
Android fails more loudly, but the lesson holds — assert that the face resolves
rather than trusting the call site. `TypefaceTests` and `FontCallSiteTests` in
the macOS suite exist because of that.

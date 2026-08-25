# The specification the Kotlin port must satisfy

Generated from `core/` on 22 August 2026. Regenerate rather than hand-edit.

Swift does not run on Android in any practical way, so the port is a
reimplementation, not shared code. That makes `core/` and its tests the
*specification*: every decision this app makes is stated there once, with tests
that say what it must do. A Kotlin `:core` that passes a translation of these
tests is, by construction, the same application underneath.

**The parity gate:** the Kotlin core's test count should match the Swift core's,
or every omission should be written down with a reason. Not because a number
means anything on its own, but because it makes silent gaps visible.


## Scale

| | |
|---|---|
| Core source | 49 files, ~6,400 lines |
| Core tests | 19 files, ~3,900 lines, **280 tests** |
| macOS layer | 28 files, ~4,500 lines — reimplemented, not ported |

## Public types, by area

Each of these is a decision the port has to make identically.

- **Model** (20) — `Activation`, `AppSettings`, `CalendarDate`, `ConfessionNorm`, `FastingSeason`, `Jurisdiction`, `LiturgicalDay`, `LiturgicalTrigger`, `Observance`, `ObservanceSettings`, `Occurrence`, `OccurrenceStatus`, `PracticeProfile`, `Reading`, `Reckoning`, `Recurrence`, `Rule`, `ShortMonthPolicy`, `Tradition`, `Weekday`
- **Practice** (2) — `DayEntry`, `Practice`
- **Recurrence** (6) — `EditPlan`, `EditPlanner`, `EditScope`, `LiturgicalDayProvider`, `NoLiturgicalData`, `RecurrenceEngine`
- **Scheduling** (12) — `Clock`, `FixedClock`, `PlannedNotification`, `QuietHours`, `ReminderLead`, `ReminderPolicy`, `ReminderTicker`, `RuleReminders`, `Scheduler`, `SystemClock`, `TimeOfDay`, `UntimedSpacing`
- **Progress** (3) — `ProgressReport`, `RuleScore`, `ScoringEngine`
- **Store** (5) — `Backup`, `InMemoryStore`, `SQLiteStore`, `Store`, `StoreError`
- **Liturgical** (5) — `HTTPError`, `HTTPFetching`, `LiturgicalService`, `OrthocalClient`, `URLSessionFetcher`
- **Glossary** (4) — `Glossary`, `GlossaryCategory`, `GlossaryEntry`, `TermMatch`
- **Prayers** (6) — `Prayer`, `PrayerBook`, `PrayerScreen`, `PrayerSequence`, `PrayerSource`, `PrayerSources`
- **Readings** (2) — `PatristicReading`, `PatristicReadings`
- **Library** (3) — `RuleCategory`, `RuleLibrary`, `RuleTemplate`
- **Presentation** (3) — `CrossGeometry`, `Format`, `RecurrenceForm`
- **Sound** (4) — `Partial`, `ToneRenderer`, `ToneSpec`, `WAV`
- **Platform** (5) — `LaunchAtLogin`, `NotificationAction`, `NotificationActionEvent`, `NotificationRequest`, `Notifier`

## Test suites to translate

| File | Tests | Suites |
|---|---|---|
| `PrayerTests.swift` | 40 | The prayers; Rules and their prayers; Where to read more; Prayer sequences; When the rope belongs; The prayers screen |
| `GlossaryTests.swift` | 25 | Glossary; Term scanning; Scanning prayer text; Scanning a run of prayers |
| `ScoringTests.swift` | 21 | Scoring; The written summary; Today counts |
| `ObservanceTests.swift` | 18 | Observance settings; Dispensations; Naming the fast-free stretches |
| `ReminderSettingsTests.swift` | 16 | Turning reminders off; Reminder lead times; Reminder settings persist; Schema migration |
| `LiturgicalTests.swift` | 15 | Orthocal decoding; Liturgical service; Remembering absences |
| `PracticeTests.swift` | 15 | A rule as it stands |
| `SchedulerTests.swift` | 15 | Scheduler; A simulated month |
| `StoreTests.swift` | 15 | Store; SQLite specifics; Settings persistence |
| `CalendarDateTests.swift` | 14 | CalendarDate; DST; Counting days |
| `RecurrenceTests.swift` | 13 | Recurrence patterns; Activation windows |
| `TraditionTests.swift` | 12 | Jurisdiction and tradition; Glossary scoping |
| `RuleLibraryTests.swift` | 11 | Rule library; App settings |
| `QuietHoursTests.swift` | 10 | TimeOfDay; QuietHours; Notifier contract |
| `ToneTests.swift` | 10 | Struck tones; WAV encoding |
| `EditPlannerTests.swift` | 9 | The three-way edit |
| `ReminderTickerTests.swift` | 8 | Reminder decisions |
| `PatristicTests.swift` | 7 | Patristic readings |
| `RecurrenceFormTests.swift` | 6 | Editing a rule loses nothing |
| **Total** | **280** | |

## The interfaces Android must supply

`core` defines these and implements none of them. They are the whole of the
platform layer, and the only places Android-specific code belongs.

| Protocol | macOS implementation | Android equivalent |
|---|---|---|
| `Store` | `SQLiteStore` (also in core — portable) | Same schema, same migration ladder |
| `Notifier` | `MacNotifier` (UserNotifications) | `NotificationManager` + channels |
| `HTTPFetching` | `URLSessionFetcher` (in core) | `AndroidHttp` — `HttpURLConnection`, no library (one GET, per day) |
| `LaunchAtLogin` | `MacLaunchAtLogin` (SMAppService) | No equivalent — Android has no login items |
| `Clock` | `SystemClock` (in core) | Direct translation |
| `LiturgicalDayProvider` | `LiturgicalService` (in core) | Direct translation |

Plus, with no protocol behind them, the two deliberate platform-glue types:
`ReminderDriver` (a `Timer` on a run loop → `AlarmManager`) and
`SettingsStorage` (an Application Support path → app-private storage).

## The database

Ported at phase 4. `:core` holds the schema, the ladder and every query behind a
four-method `Db` interface, so the SQL runs on JDBC in the tests and on
Android's own SQLite later, and `:core` still depends on nothing platform-bound.

**The schema is identical; the contents of the JSON columns are not.** Kotlin
writes its own encoding for `recurrence`, `time_of_day` and `prayer_ids`, so a
macOS database does not open on Android. That follows from ruling out sync, and
is written down because the matching schema invites the opposite assumption.

One SQLite file, WAL mode, schema at **version 6** with a forward-only
migration ladder in `SQLiteStore.migrate()` (five steps, each stamping
`schema_version`). Tables: `rule`, `activation`, `occurrence`, `app_settings`,
`liturgical_day`, `schema_version`.

Two things that matter more than they look:

- **A file copy must include `-wal` and `-shm`** or it silently loses recent
  writes. This has bitten once already.
- **The legacy-database fixture** exists because a migration was twice written
  to reverse only the newest change. Whatever the Kotlin store uses, keep an
  equivalent test that opens an old database and migrates it forward.

## Content that must not be re-typed

The prayers, the glossary, the rule library and the patristic readings are data,
not logic — and three of the four are liturgical text where a transcription
error is a real error, not a typo.

- 18 prayers (Hapgood 1906, public domain) + 4 sequences
- ~110 glossary entries across 8 categories
- The rule library templates
- Patristic readings (ANF/NPNF, public domain)

**Done at phase 8, mechanically.** A Swift test writes the whole of it to
`android/core/src/main/resources/content/*.json` and **fails if what is
committed no longer matches the Swift content**, so the two platforms cannot
say different things without CI noticing.

The Swift literals stay the place content is authored. They carry the provenance
in their comments — Hapgood 1906, ANF and NPNF, which prayers are counted on a
rope and why — and JSON holds none of that.

The wire shape is designed rather than dumped. Swift's own encoding of a
recurrence is `{"liturgical":{"_0":{"season":{"_0":"greatLent"}}}}`, which is
unreadable and awkward to decode elsewhere — and is also the shape already
written into the `recurrence` column of every existing database, so it could not
have been changed even if it were pleasant.

To regenerate after editing content:
`CHOTKI_WRITE_CONTENT=1 swift test --package-path core --filter ContentExport`


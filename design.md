# chotki — Design

A menu bar app for keeping an Orthodox prayer rule, and honestly measuring whether it is kept.

Status: design complete. No code written yet.
Started 2026-08-19.

## The problem

A calendar app tells you what is scheduled. It does not tell you what you actually kept, and mixing a prayer rule into a work calendar buries it. The product insight: the value is not the schedule, it is the honest record of consistency over months — recorded in a way that does not turn the practice into a scoreboard.

The rule is expected to be built up piecemeal over a long period, with tasks arriving from other people. Nothing may assume a fixed or complete set of tasks.

## Tone — a hard constraint

The app is **encouraging, never shaming.** This is a product requirement, not a styling preference, and it outranks any later idea that would make the tracking "more motivating".

Concretely, and non-negotiably:

- No red for a missed rule, no "failed", no ✗, no warning iconography anywhere in the progress surfaces.
- Never shame a broken streak. A streak ending is reported neutrally or not at all; it is never the headline.
- Never compare the user against a past better self ("down from 94%"), against a target, or against anyone else.
- Missing something is reported as information, not as a verdict: which rule, which days, whether there is a pattern worth noticing.
- The prose summary leads. The number is secondary and can be hidden entirely in settings.
- Pausing a rule is a first-class, unpenalised action. Taking less on is a legitimate outcome, not a failure state.
- No guilt-based notification copy. A reminder says what is due, never how long it has been outstanding.

If a future change makes the app feel more like a habit-streak tracker, that change is wrong regardless of how well it tests.

## Observance — participation is never assumed

Fasting and feast-keeping are each settable to one of three states, independently:

- **hidden** — absent from the calendar entirely; it looks like an ordinary calendar
- **shown** — annotated on the calendar as information, and nothing more: no task, no reminder, never scored
- **observed** — part of the rule; liturgical recurrences fire and are scored

The default for both is **shown**, not observed. The app begins by telling you what the day is; taking something on is always a deliberate act.

This exists because people arrive with real constraints. A health condition can make fasting unsafe. Someone with no parish within reach cannot attend a Liturgy on a great feast. Neither is a failure, and the app must not be capable of representing it as one — so an observance that is not `observed` produces no due days at all, which means it cannot be missed and cannot reach the score. Standing an observance down is structurally identical to pausing a rule.

Two consequences for the interface:

- **Fasting is reported, never prescribed.** The app says "the calendar marks this as a strict fast", not "do not eat meat, fish, dairy". It is describing the church calendar, not issuing dietary instruction to someone whose doctor or priest may have said otherwise. The abstention list from orthocal is displayed as what the day is, never as what the user must do.
- **No justification is ever requested.** The setting is three options with no explanatory prompt, no "why?", and no disclosure of a medical reason. Changing it is not an event the app comments on.

## Education — the app teaches as it goes

The calendar this app displays is full of language a newcomer cannot decode: "Major Feast of the Theotokos", "Leavetaking of the Nativity", "Tone 2", "Ven.", "Fish, Wine and Oil are Allowed". Looking each one up elsewhere breaks the thing you were doing.

So any explained term appearing anywhere in the interface is tappable, and opens an **Education** pane that explains it. Every term is also indexed there, browsable by category and searchable, so the pane works as a reference in its own right rather than only as a destination.

Mechanically this is `Glossary.scan(_:)` in core, which finds known terms in arbitrary text. Three properties make it usable rather than noisy:

- **Longest match wins** — "Great Feast" is one term, not "Feast" inside it.
- **Word boundaries are required** — otherwise "Fast" lights up inside "Breakfast".
- **Matches never overlap**, and are returned in reading order.

Content is bundled, not fetched: it must work offline and must not change under the reader. Entries carry a one-line summary for inline display, a fuller explanation for the pane, aliases (the calendar prints "Ven." where a reader would search "venerable"), optional pronunciation, and cross-references, which are tested to resolve so the pane can never present a dead link.

> **The glossary content needs review by a priest.** It was written to be accurate and introductory, but it is not authoritative, practice varies between jurisdictions, and anything touching fasting or preparation for communion should come from a priest rather than from software. Entries say so where it matters.

## Jurisdiction — calendar and practice are separate axes

A person chooses their church, and the app reflects that church's customs. Two independent properties come out of that choice:

- **Reckoning** — Julian or Revised Julian. Decides which civil date carries which fixed feast.
- **Tradition** — Russian, Greek, Antiochian, Romanian, Serbian, Bulgarian, Georgian. Decides terminology and customary practice.

They do not track together, which is why they are separate types. The OCA is Russian in tradition but New Calendar in reckoning; the Patriarchate of Jerusalem is Greek in tradition but Old Calendar. Collapsing them into one setting would get both wrong.

Each tradition carries a `PracticeProfile` describing what is customary — most importantly how confession relates to communion, which is the difference newcomers trip over most. Russian and Serbian usage expects confession before each communion; Greek and Antiochian usage generally does not. That is a genuine difference between traditions, not a difference in strictness.

Three constraints on anything built from this:

- **Descriptive, never prescriptive.** The app reports what is customary and names who to ask. It never tells anyone what they must do. Every practice note is tested to acknowledge variation or point to a priest, and tested to contain no instruction language.
- **A jurisdiction's practice is overridable.** A parish sometimes differs from its jurisdiction's norm, so the profile is a starting point and the app shows what was actually set.
- **The glossary is scoped.** Terms specific to one tradition are shown only to that tradition — a Greek reader is not told about the Kursk Root Icon as though it were common to all Orthodoxy. Cross-references are pruned when scoping, so the education pane can never link to an entry the reader cannot open.

## Reminders — silence is not standing down

Notifications are controllable at two levels, and neither touches whether a rule is kept.

- **Master switch.** `ReminderPolicy.notificationsEnabled` stops every reminder in the app.
- **Per rule.** Each rule carries `RuleReminders { enabled, leads }`.

The binding property: **turning reminders off changes nothing about whether a rule is due or how it is scored.** Someone who knows their own morning routine should be able to stop the buzzing without the app quietly deciding they have given the rule up. Standing a rule down is pausing it, which is a different action with a different meaning, and the two must never be conflated. This is tested directly.

Lead times are chosen per rule, from: at the time, 10 minutes, 30 minutes, 1 hour, 2 hours, the evening before. A rule may carry **several** leads at once — an hour before to get ready, ten minutes before to actually leave — which is why each lead gets its own notification id, and why cancellation on completion covers every lead rather than only the next one.

Two details that follow:

- **The evening before** fires at a fixed 20:00 the previous day rather than at an offset, because for something you travel to, "the night before" is a time of day rather than a duration.
- **Rules with no settings** fall back to the policy default rather than storing a copy, so changing the default moves every rule that never expressed a preference.

## Scoring, in practice

Settled in Phase 6, and enforced by tests:

- A day counts only once its moment has passed. A rule due at 21:30 is not missed at noon.
- `completed` scores 1, `completedLate` scores 0.5 — it was still done. Missing scores 0.
- `skipped`, `cancelled` and `moved` leave both sides of the ratio.
- Days within 30 carry full weight; beyond that weight halves every 60 days. It never reaches zero, because what someone kept in the spring still happened.
- Nothing due yet yields **no figure at all**, not a zero. A zero would be a lie.
- A streak steps over stood-down days rather than breaking on them, and is stated as a fact ("25 in a row"), never as something at risk.
- The prose names a weekday pattern only when every slip shares one and there is more than one slip. Otherwise it is noise dressed as insight.

## Taking a rule on must never be a no-op

A rule tied to the church calendar produces no due days while its observance is `shown` rather than `observed` — and `shown` is the default. Taking on the Wednesday and Friday fast therefore added a rule that could never appear, with nothing said about why.

Two rules follow, both tested:

- Taking on a rule that depends on an observance **turns that observance on**, and says so in a notice. Taking a rule on is a statement of intent; adding something that silently does nothing is worse than refusing.
- The library says so **before** the click too, so the change is never a surprise.

A test asserts that every liturgical template declares its `requiredTrigger`, so a new one cannot be added that quietly does nothing.

## Two front doors

Chotki is both a menu bar app and a full application, and the menu bar item is the one that is never optional.

- **The menu bar popover** is the quick path: today's rules, mark something kept, the day's reading. Fixed 400×560.
- **The window** is the roomy one, with a sidebar and the month grid beside the day's rules rather than stacked above them. It carries a Dock icon, and the same content laid out for the space.
- **`showInDock`** switches between the two live, without relaunching: the activation policy moves between `.regular` and `.accessory`, and the Dock icon and menu bar are installed or torn down to match. With it off, the app is menu-bar-only exactly as before.

Both surfaces share one `AppModel` and the same content views. The split of each screen into `XView` (scroll chrome) and `XViewContent` is what makes that possible — the window arranges the same content differently rather than duplicating it, and `DayPanel` is shared outright.

The model still knows nothing about windows: it exposes `openMainWindow` and `onDockPresenceChanged` as closures the delegate fills in.

A regular app needs a menu bar, and an Edit menu specifically — cut, copy, paste and select all reach a text field through the responder chain from those menu items, not from the field itself. Without it, editing shortcuts silently do nothing.

## The bundled passages

Thirty-six short passages from the Fathers, shown one a day beneath the scripture, chosen by day-of-year so the same day always gives the same passage.

Bundled rather than fetched: there is no reliable free API for patristic texts, scraping one would be brittle, and a passage that fails to load is worse than a small set that always works.

**Every source is public domain by construction** — the Ante-Nicene Fathers and Nicene and Post-Nicene Fathers series (1885–1900), and early translations of the Sayings of the Desert Fathers. Modern translations, the Philokalia especially, remain in copyright; a test rejects any source naming one, so the rule is enforced rather than remembered.

Each passage names its work so the attribution can be checked. They await a priest's review before the app is used by anyone but its author.

## Settings live in the store

Not in `UserDefaults`. They were, and they were **not persisting at all** — the preferences domain never existed, so every setting reverted on the next launch. The visible symptom was a fast rule that vanished: taking it on turned fasting to `observed`, that setting was lost, and the rule went back to being unable to come due.

They now sit in the database beside the data, which is what the design said all along: what someone has chosen travels with their record, survives a move between machines, and is carried in a backup. Anything left in the old location is migrated once.

Two repairs run on load, because a stored flag can be wrong about the world:

- **A stranded rule turns its observance back on.** A rule on the calendar whose observance is not observed can never come due — it is on the list and invisible. That can happen to a rule taken on before this was handled, or restored from an older backup.
- **Someone with rules has plainly been here before**, whatever `hasCompletedFirstRun` says, so they are not shown the first-run screen.

## Reminders do not fire in a burst

A reminder more than fifteen minutes past its moment is marked handled and stays quiet. Without this, launching in the afternoon — or a rule becoming due mid-day, which is exactly what happens when an observance is turned on — fires every earlier reminder for the day at once.

## The prayer rope chime

Synthesised, not shipped. There is no audio file anywhere in the project, for the same reason there is no icon file: it cannot drift from the design, it needs no licence, and it works on any platform.

A bell is not a sine wave. Its partials are **inharmonic** — hum at 0.5, prime at 1.0, tierce at 1.19, quint at 1.5, nominal at 2.0 — and each decays at its own rate, the high ones fastest. The tierce is the minor third that gives a bell its slightly mournful colour. Whole-number ratios alone would sound like an organ.

Two sounds, deliberately unlike each other, because they are heard with the eyes closed:

- **The chime** marks a completed knot: 587Hz, seven partials, ringing out over about two and a half seconds.
- **The tick** only confirms a press landed: 1.6kHz, 50 milliseconds, quiet. Well above the bell and far shorter, so the two can never be mistaken.

Never both at once. On the final knot the chime sounds alone.

The synthesis lives in core as pure arithmetic and is tested without a sound card — that nothing clips, that it fades in rather than clicking, that it decays rather than holding, and that the tick stays subordinate to the bell. Only playback is platform-specific, and the tick uses several players in rotation because one restarted mid-sound cuts itself off, and a click that never arrives is worse than none when you are listening for it.

## Keeping the record

The value of this app is entirely cumulative: a year in, the database is the only copy of something that cannot be reconstructed. So there are three ways out of it.

- **Automatic**, once a day on launch, to `Application Support › Chotki › backups`, keeping the last ten. It depends on nobody remembering anything.
- **Export**, from settings, to anywhere.
- **Restore**, from settings, which **merges** — nothing already present is removed. A restore that silently wiped a month of record would be far worse than a duplicate.

Two guards, both learned the hard way:

- **An empty backup is never written.** If the store failed to open, or this is a fresh install, an empty file is worthless and could replace a good one.
- **Tests never write backups.** `AppModel` takes `writesBackups`, false in tests. The suite had already written a 0-rule backup into a real user's Application Support before this existed — the second time test code reached the real machine, after the preferences files. Anything a test constructs must be told not to touch the world.

## Progress speaks only about finished days

The window ends **yesterday**. Today is outside it entirely, and the report says so: "Your progress up to Tuesday 18 August."

A day still in progress is not a verdict. Without this, a rule added in the morning and not yet kept counted against someone before they had had the chance — and a rule kept today appeared or not depending on whether its hour had passed, which made the report look arbitrary.

Related, and separate: **elapsing gates misses, not keeping.** A day that was actually kept counts from the moment it is marked, whatever the clock says. Marking something complete is a fact, not a pending judgement.

## Marking a day you forgot to tick

Any day the rule was in force can be marked afterwards, and doing so records it as **kept** — not as kept late. Forgetting to tick a box is not the same as doing something late, and the app cannot tell the difference, so it trusts the person rather than guessing against them. Recording something as late is available in the menu as a deliberate choice.

Un-ticking **removes the record**, restoring the day to due-or-missed. It previously wrote `.skipped`, which quietly excused the day and made the checkbox indistinguishable from standing the rule down.

## Dispensations — when the Church lifts a rule

The Wednesday and Friday fast is not kept in four stretches of the year: Bright Week, the week after Pentecost, the week of the Publican and the Pharisee, and the days between the Nativity and Theophany. orthocal already reports these as `fast_level: 0` with exception `Fast Free`.

The naive handling is to let the rule produce no due day, which the app did. That scores correctly but **looks like a bug**: the rule simply vanishes from the list with no explanation, and the person learns nothing.

So a dispensed day is a third state, alongside due and not-applicable:

- It is **not due** — it cannot be missed, it is not scored, and it raises no reminder.
- It is **still shown**, ticked, with the reason beneath: "Not observed during Bright Week."
- It cannot be marked or cleared, because nothing was asked of anyone.

The period is named from the calendar's own data rather than by recomputing dates: Bright Week names itself in the title, the others sit at fixed distances from Pascha or on fixed old-style dates.

Dispensation applies to rules in the **fasting category**, keyed on the category rather than the recurrence so it holds for a rule written by hand as much as one taken from the library.

## A template must fall on the days its name claims

`wednesday-friday-fast` was modelled as `.liturgical(.fastDay)`, which means *any* day the calendar marks as a fast. Through the Dormition Fast, Great Lent and the Nativity Fast, that is every single day — so a rule called "The Wednesday and Friday fast" appeared on roughly 180 days a year, mostly the wrong ones.

It is now `.weekly(days: [.wednesday, .friday])`, which is what it says, with the fast-free stretches handled as dispensations rather than by changing which days apply.

A test walks a full year for every template and asserts the count matches the promise: about 104 for the weekly fast, 365 for a daily rule, 52 for a weekly one.

## Never re-case text that came from the calendar

"Wednesday of the 12th week after Pentecost" is how the Church writes it. The reading tab was lowercasing it, along with "Vespers" and "Dormition Fast", and the result looked careless rather than styled.

The rule: the app's **own** labels are lowercase by design — section headings, the legend, category names. Anything that arrived from orthocal is shown exactly as it came.

## The marks

Two drawn in code, like the icons, so nothing can drift from the palette and nothing needs an asset.

- **A faint eight-pointed cross**, anchored to the bottom of the Rule tab where the panel would otherwise be blank. Centred, it struck through the calendar and read as stray lines; at the bottom it reads as a cross. Seven per cent opacity — noticed once, then never competing with the text.
- **The rope mark**, small in the corner: a loop of knots with the cross hanging from it, which is what a chotki actually is and what the app is named for.

Both live in `RuleBackdrop`, shared by the app and the offscreen renderer so the two draw the same thing.

## Fixed facts

- Single user, single machine. Local storage only, no account, no sync, no telemetry.
- macOS 13+ first (MenuBarExtra requires it). Swift 6.1.2. Windows and Linux planned.
- Tests use **swift-testing** (`import Testing`), not XCTest. XCTest ships with Xcode and is absent from the Command Line Tools; swift-testing is present in both CLT and the Linux toolchain, so one framework covers every platform. Discovered 2026-08-19 when XCTest failed to resolve.
- Ad-hoc signing is sufficient for notifications, including actions. Verified end to end 2026-08-19; no Developer ID required for personal use.
- Xcode is NOT installed and is NOT needed. Command Line Tools SDK 15.5 compiles SwiftUI + UserNotifications cleanly (verified 2026-08-19 with a MenuBarExtra probe target). Build with SwiftPM, assemble the .app bundle by script, sign ad-hoc.
- Repository: https://github.com/Orthobro83/chotki — public, MIT, branch `main`. Personal context lives in `context.local.md`, which is gitignored and must never be committed.
- orthocal's URL takes a **civil** date; the response body reports the date in the requested reckoning. `/api/julian/2027/1/13/` answers with year 2026, month 12, day 31. The cache is keyed on the civil date and the reported date is stored as data. Discovered 2026-08-19.
- orthocal codes: `fast_level` 0 none, 1 Wednesday/Friday, 2 Great Lent, 3 Apostles, 4 Dormition, 5 Nativity. `fast_exception` 11 is Fast Free; other exceptions relax a fast rather than lifting it. `feast_level` 7 and 8 are the Major Feasts of the Theotokos and of the Lord — the Great Feasts; lower levels are ranked days.
- Liturgical data source: `orthocal.info` — free public JSON API, no key. `/api/julian/YYYY/M/D/` for Old Calendar, `/api/gregorian/YYYY/M/D/` for New. Returns tone, commemorations, feast level, fast level, abstentions, and full scripture passage text. It is the only network call the app makes.

## Calendar facts (settled 2026-08-19, worth not re-deriving)

- Julian vs Gregorian reckoning does NOT affect days of the week. Wednesday is Wednesday in every jurisdiction. The Wed/Fri fast rhythm never moves.
- Nearly all Orthodox churches, New Calendar included, compute Pascha on the Julian reckoning. So the movable cycle — Pascha, Great Lent, Pentecost, Apostles' Fast — is IDENTICAL for Old and New Calendar churches. Only fixed feasts differ, by 13 days.
- Consequence: disagreement between reckonings is concentrated around Nativity and Theophany, not scattered through the year. Verified example — Wednesday 13 Jan 2027 is a strict fast on the New Calendar and fast-free (Leavetaking of the Nativity) on the Old.
- Adherents by reckoning, nominal: Julian ~110M (Russian ~100M, Serbian ~8M, Georgian ~3.5M, Jerusalem, Polish) against Revised Julian ~47M (Romanian ~18M, Greek ~10M, Ukrainian OCU ~7M, Bulgarian ~6M, Constantinople, Antiochian, Cypriot, Albanian). Figures are soft, but the Russian Church alone outweighs all Revised Julian churches combined, so the ordering is robust.
- The app always DISPLAYS civil Gregorian dates — the same grid as a wall calendar. Reckoning is a lookup layer, never a display layer.

## Decisions

### Platform and portability

- 2026-08-19 — macOS first with SwiftUI, Windows and Linux to follow. Chosen over Tauri and Electron for time-to-usable; the portability cost is paid by the core/UI split below rather than by the framework.
- 2026-08-19 — `core/` is a pure SwiftPM package importing ONLY Foundation and SQLite. No AppKit, no SwiftUI, no UserNotifications, no SMAppService, no Apple-only API of any kind. Swift compiles on Windows and Linux; SwiftUI does not. This is what makes the port a UI rewrite rather than an app rewrite.
- 2026-08-19 — Core test suite runs on Linux in CI from Phase 2, before any Linux app exists. Portability that is not tested rots silently; this makes an Apple-only import fail loudly the day it is added.
- 2026-08-19 — Platform services sit behind protocols DEFINED in core and IMPLEMENTED per platform: `Notifier` (show a notification, offer actions), `LaunchAtLogin`, `TrayPresenter`.
- 2026-08-19 — Scheduling lives in core, not in the OS. The app is tray-resident and always running, so an in-process scheduler decides WHEN and the platform `Notifier` only SHOWS. This is portable, testable without a running desktop, and removes any dependency on `UNUserNotificationCenter` scheduling behaviour.
- 2026-08-19 — **Changed during Phase 2:** GRDB dropped in favour of the SQLite C API through a `systemLibrary` target. GRDB's Linux support is weaker than the portability rule this project enforces, so depending on it would have meant the CI guard policing a rule the dependency could not keep. sqlite3 is present on macOS, Linux and Windows alike, and the dependency count stays at zero. Storage still sits behind a `Store` protocol, with `InMemoryStore` and `SQLiteStore` both implementing it and both covered by the same test suite.
- 2026-08-19 — No date FORMATTING in core. Core returns dates and values; presentation belongs to the UI layer, which differs per platform anyway.

### Product

- 2026-08-19 — Named `chotki` (the prayer rope).
- 2026-08-19 — Default reckoning is Julian, on adherent numbers rather than on any one jurisdiction. Fully configurable.
- 2026-08-19 — Jurisdiction is a setting `{ name, reckoning, endpoint }`; every date-aware surface reads through it. Switching invalidates the cache and refetches; no other code reacts.
- 2026-08-19 — Explained terms are tappable everywhere they appear, opening an indexed, searchable Education pane. Bundled and offline. See the Education section above.
- 2026-08-19 — Fasting and feasts are each independently `hidden` / `shown` / `observed`, defaulting to `shown`. See the Observance section above, which is binding for the same reasons the Tone section is.
- 2026-08-19 — Nothing ships switched on. Bundled rules are a library taken from one at a time. First launch invites two or three, not twelve.
- 2026-08-19 — Enabling a template COPIES it into the user's rule. It does not stay linked. A rule written from scratch is structurally identical to one taken from the library.
- 2026-08-19 — Every rule carries an optional `note` and `source` — who suggested it and why. Rules arrive from other people over months; their origin matters later.
- 2026-08-19 — Tasks carry a LIST of activation periods, not an on/off flag. This one structure gives enable-later, pause-without-penalty, resume, and seasonal rules for free.
- 2026-08-19 — Pausing excludes those days from scoring (`skipped`), never counts them as missed. Deleting archives and preserves history. Nothing the user actually did is ever destroyed.
- 2026-08-19 — Scoring counts only occurrences whose due time has passed AND that fall inside an activation period. Weighted to the last 30 days; older days decay but never vanish. `completedLate` scores partial, not zero.
- 2026-08-19 — The progress report leads with prose, then the figure. A setting hides the number entirely. Reaffirmed 2026-08-19: encouraging, never shaming. See the Tone section above, which is binding.
- 2026-08-19 — Untimed tasks are reminded up to four times a day, bounded by quiet hours (default 21:30–06:30).
- 2026-08-19 — **Changed during Phase 4:** those reminders are spread evenly across the waking day (07:00, 12:00, 16:00, 21:00) rather than fired hourly. Hourly with a cap of four clustered every reminder before 10am and then went silent for fourteen hours — four nudges before breakfast, and nothing at the point in the evening when an unkept rule is actually still keepable. The literal hourly cadence remains available as `ReminderPolicy.hourly`.
- 2026-08-19 — **Decided during Phase 4:** quiet hours do NOT suppress reminders for rules with a set time. They exist to stop unsolicited repetition, not to silence a reminder the user asked for. With the default window ending at 06:30, a 06:30 morning-prayers rule has a lead time of 06:20 — inside the quiet window — and silencing it would make the app useless for exactly the rule people most want kept. This settles the open question about shifting the quiet window: no shift is needed.
- 2026-08-19 — Notifications carry mark-complete and snooze actions. Completing from the banner matters more for adherence than the score does. Linux notification daemons vary in action support, so the UI must degrade to a plain notification without losing the reminder.
- 2026-08-19 — Store all-day dates as calendar dates, never timestamps. A timestamp shifts a day under DST and the bug surfaces months later.
- 2026-08-19 — Editing/deleting a repeating rule always offers three choices: this day only, this and future, whole series. This determines the schema; retrofitting it is a rewrite.
- 2026-08-19 — Reading tab prefetches 14 days ahead and caches. The app never blocks on the network and never shows a spinner where text should be.
- 2026-08-19 — Saint quotes ship as a bundled local file of public-domain patristic text (Nicene & Post-Nicene Fathers). Philokalia translations are still in copyright; scraping is brittle and unnecessary.

## Repository layout

    core/            pure SwiftPM package — Foundation + SQLite only
      Model/         Rule, Activation, Occurrence, LiturgicalDay
      Recurrence/    expansion, activation intersection, the three-way edit
      Scoring/       weighting, streaks, prose summary generation
      Liturgical/    orthocal client, cache, jurisdiction
      Scheduling/    in-process scheduler; Notifier protocol
      Platform/      LaunchAtLogin, TrayPresenter protocols
    macos/           SwiftUI menu bar app — the only Apple-specific code
    .github/         CI: build + test core on macOS AND Linux

## Data model

Four tables, SQLite.

    Rule
      id, title, note, source
      recurrence      -- daily | weekly(days) | monthly(day)
                      -- | liturgical(season | fastDay | feast)
      timeOfDay: Time?   -- nil means "anytime today"
      category, createdAt, archivedAt

    Activation         -- many per rule; this is the pause mechanism
      ruleId, from: Date, to: Date?    -- nil `to` means currently in force

    Occurrence         -- written ONLY on deviation from default
      ruleId, date: CalendarDate
      status: completed | completedLate | skipped | moved | cancelled
      completedAt: Date?

    LiturgicalDay      -- cache, keyed by (date, reckoning)
      date, reckoning, fastLevel, fastException, abstentions
      feastLevel, commemorations, readings, fetchedAt

Everything else is computed. A day with no Occurrence row and a covering Activation is simply due — or, once its time has passed, missed. Absence is the default state, not a record.

## Interface

- Left click opens the popover (380–420pt wide). Right click gives a quick menu: mark next task done, snooze, open progress, quit.
- Menu bar icon is an eight-pointed Orthodox cross supplied as a TEMPLATE image so macOS inverts it in both menu bar appearances. Windows will need an ICO; Linux needs themed icons and, on GNOME, a shell extension — a platform limitation, not a stack choice.
- Three tabs. **Rule** — month grid plus today's list. **Reading** — the day's commemoration and scripture. **Progress** — the report, which can also open detached into a proper window.
- Palette: deep charcoal ground, byzantine gold for today and for completion, muted violet for fasting seasons, ochre red for liturgy days. Restraint is the point; ornament reads as kitsch at 12pt.
- Optional secondary date line — "19 August · 6 August o.s." — so a parish bulletin and a wall calendar can be reconciled at a glance.

## Out of scope for v1

- iCloud or cross-device sync. Store is local; backup is JSON export.
- Any network call other than orthocal. No analytics, no account, no telemetry.
- A mobile companion.
- Notarisation and store distribution. Ad-hoc signed.
- Multiple profiles or households.

## Open questions

- Quiet hours default 21:30–06:30 — should the window shift if morning prayers are set earlier?
- Should a great feast propose a Liturgy task automatically, or wait behind a prompt?

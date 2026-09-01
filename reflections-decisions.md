# Reflections — seven days, kept as a journal

Decision record for the Reflections section of the Chotki **macOS** app, and for
the typeface change that comes with it.

Status: **built on macOS.** `core` and the macOS interface are done and tested;
iOS and Android are not started. This document is the specification;
`reflections-mockup.html` beside it was the layout it was designed against and
is now superseded by the real screens.

What exists, in `core/Sources/ChotkiCore/Reflections/`: `Reflection`,
`ReflectionQuestion`, `ReflectionEntry`, the seven seeded verbatim,
`ReflectionPeriod`, `ReflectionSeries`, `ReflectionJournal`, `ReflectionArchive`
and `ReflectionImport`; four `Store` methods with both implementations, schema
version 7, seeding, export and import. Seven library templates, one per weekday.

In `macos/Sources/Chotki/`: `ReflectionsView` / `ReflectionsViewContent`,
`ReflectionOverlay`, the sidebar section, and `Theme.reading` — the app-wide
reading face. The render harness draws the section, the scrolled section, its
foot, and the overlay.

433 core tests and 78 macOS tests, all passing.

What does not exist: the iOS and Android views. See §8.1.

Source material: `~/Downloads/nepsis-seven-reflections.html`, from the
Brotherhood of the Narrow Path. The seven prompts and the closing text below are
transcribed from it verbatim and must not be reworded.

---

## 0. The name

The section is called **Reflections**, not Nepsis.

*Nepsis* is a precise ascetic term — watchfulness, sobriety, the guarding of the
heart — and naming a whole section after it claims more for the section than it
does. What is there is a journal: seven questions and the answers to them over
time.

There is a second, mechanical reason. `GlossaryCoverageTests` scans everything
bundled and fails on a term of art the glossary cannot explain. "Nepsis" in the
interface would oblige a glossary entry, and per `CLAUDE.md` writing the
definition of a religious term is not mine to do. "Reflections" carries no such
debt. The word may still belong *inside* the feature, in the prompts' own text,
where it can be glossed deliberately.

Dropped with the name: the masthead, the νῆψις subtitle, the Reflect button, the
side rails, the prosphora seal and the hairline bands.

## 0.1 Scope

**macOS only.** A new sidebar section in `MainWindowView`, filling the whole
detail pane — no calendar column, no day column beside it. Not in the popover:
at 400 points this is unusable, and the popover's job is the day's rule. **No
entry is added to `PortParityTests`** until it ships on iOS and Android; adding
one now would fail CI on two platforms that correctly do not have the feature.

---

## 1. The seven

One reflection per weekday, Sunday through Saturday, in the order they appear in
the source. Each has two parts, kept structurally distinct: `notice`, what to
attend to during the day, and `task`, what to write at the end of it.

### Sunday — Notice the Resistance

**Notice.** Pay attention today to the moments where you feel resistance, irritation, or quiet refusal. Not the big things. The small ones. The conversation you avoided. The prayer you skipped. The moment you reached for your phone instead of sitting with a thought.

**At the end of the day.** Write down two or three moments where you felt resistance. Do not analyze them yet. Just notice.

### Monday — Notice the Quiet

**Notice.** Pay attention to where your inner life has gone silent. Where have you stopped praying about something you used to pray about? Where have you stopped caring about something you used to care about?

**At the end of the day.** At the end of the day, write down one area of your life that has quietly gone silent.

### Tuesday — Notice the Comfort

**Notice.** Pay attention to the things you reach for to soothe yourself. Phone. Food. Music. Distraction. Not to judge them. Just to see them.

**At the end of the day.** At the end of the day, write down what you reach for when you do not want to feel something.

### Wednesday — Notice the Avoidance

**Notice.** Pay attention to what you are avoiding. The conversation you keep putting off. The confession you have not scheduled. The relationship you are letting drift. The thought you keep pushing away.

**At the end of the day.** At the end of the day, write down one thing you have been avoiding.

### Thursday — Notice the Pattern

**Notice.** Look back at what you have written so far this week. What is the pattern? What keeps showing up?

**At the end of the day.** At the end of the day, write down what you are starting to see about yourself.

### Friday — Notice the Cost

**Notice.** If you keep going the way you have been going, where does it lead? Look at the patterns honestly. What is this costing you spiritually? What is it costing the people around you?

**At the end of the day.** At the end of the day, write down what you are putting at risk by staying where you are.

### Saturday — Bring It Forward

**Notice.** Look at everything you have written this week. This is the honest picture of where you are. Identify one thing from this week's noticing that you need to bring to confession. Identify one thing you want to talk to your spiritual father about. Go to liturgy. Stand. Pay attention. Receive communion if you are prepared and have your priest's blessing.

**At the end of the day.** At the end of the day, write down what you are taking forward from this week and what changes when you do.

## 2. What can and cannot change

**There is exactly one reflection per weekday, always.** No adding, no removing.

**Editing replaces the question from that day onward.** The old wording is not
deleted — every answer already written keeps the question it was written
against, and stays readable through the overlay. The edit screen says so plainly
before the change is saved.

**The snapshot rule.** Because questions are editable, an answer cannot merely
point at its question — the wording would change under every past answer the
moment the question was edited, and an answer read a year later would be
answering something that was never asked. **Every entry stores its own copy of
the title, `notice` and `task` as they stood when it was written.** This is the
central consequence of editable prompts and the thing most likely to be got
wrong by a later change.

**Answers lock on save.** Once written and saved, an answer cannot be edited or
deleted. Save asks for confirmation first, because the action is irreversible —
but there is **no standing notice** under the text field saying so. A permanent
warning beside every empty box is a nag, and the tone rules in `design.md` rule
that out. The guard belongs at the moment of the action, not in the furniture.

## 3. The overlay

Each weekday header carries a control naming how many past entries it holds.
Opening it raises an overlay over the section:

- The question **as it stood on that date**, then the answer, both scrollable.
- **◀ ▶** on either side of the pane, walking **that weekday's** entries only —
  from Sunday back through Sundays. Position reads "2 of 3 Sundays". The arrows
  disable at each end rather than wrapping.
- A **jump to** pop-up listing the dates directly.
- **Year** and **month** pop-ups scoping what the arrows and the jump-to offer.
  This is where the period selector lives; the section itself has no date
  controls, because two sets on one screen is one too many.
- Closed by the ×, by clicking outside, or by Escape. ← and → also step it.

## 3.1 The header, and what the section says it is for

The section carries its own header row, all left-aligned: **Reflections**, a
question mark in a circle, and **Add this as a daily rule**.

**The help mark** brings down an explainer over the top of the section — Ryan's
words, held in `core` as `Reflection.explainer` for the same reason `Welcome`
lives there: the alternative is the same paragraph typed into three languages,
which is how the Mac and Android came to disagree about several other things.

It slides down from the top with `.move(edge: .top)` and fades, over 0.28s.
Two details that were got wrong first:

- It starts **below** the header rather than at the very top. Its last line
  tells the reader to click a button beside the help mark, and covering the
  thing you have just been told to press explains nothing.
- It sits in the **same column** as the content. Centred, it stood 50 points to
  the right of everything it was explaining.

It comes down *over* the section rather than pushing it apart, so nothing under
it moves and the place someone was reading stays where they left it.

**The link** is `Welcome.brotherhoodURL` — the address already in the app, and
already Ryan's. Not a second one found for the same place. A test asserts there
is exactly one link in the explainer and that it is that constant.

**The button** puts all seven on the rule in one action: one question a day,
each on its own weekday. Its label is `Reflection.addAsRuleLabel`, and the last
paragraph of the explainer quotes that same constant — so renaming the button
cannot leave the text telling someone to click something that is not there. A
test proves it.

Already-taken is matched **on title**, because a library template copies itself
and keeps no link back. A renamed copy therefore stops counting, and that is
right: it is his rule then, not this one. Once all seven are on, the button is
replaced by a plain "On your rule" — stated as a fact, not as praise and not as
a prompt to do more.

## 3.2 Neither half of the question is labelled

The `notice` had a "Notice" label in the margin and the `task` had none. Both
are now unlabelled, told apart by weight alone.

The task lines say "At the end of the day…" themselves, so a label there read
twice — and a label reading "Notice" in the margin only named what the whole
section is already called. Removing both also gives the text the full column,
which matters when the notice runs to four lines.

## 4. Typeface

The reading face becomes **Iowan Old Style**, throughout the app, not only here.

### It cannot be shipped with the app

Iowan Old Style is John Downer's, released through Bitstream and licensed to
Apple. It is a commercial font. **Bundling it in the app would be a licence
violation**, so it is not bundled, and "ship it so we do not fail backwards"
is answered by a fallback chain instead.

It ships with every stock macOS and iOS — `/System/Library/Fonts/Supplemental/Iowan
Old Style.ttc`, faces `IowanOldStyle-Roman`, `-Bold`, `-Italic`, `-BoldItalic`,
with `-Titling` also present — so on Apple platforms it is there in practice.
It sits in *Supplemental*, which a user can disable in Font Book, which is why
the chain below exists rather than a bare `Font.custom`.

### The chain

1. `IowanOldStyle-Roman` — what we want.
2. `Charter-Roman` — the fallback. Also on every stock macOS
   (`/System/Library/Fonts/Supplemental/Charter.ttc`).
3. `.system(design: .serif)` — New York. Cannot fail.

**Charter is the right fallback on the merits, not just by availability.**
Matthew Carter, 1987, also originally Bitstream, drawn to the same brief as
Iowan: large x-height, low stroke contrast, sturdy blunt serifs, engineered to
stay legible at text sizes on coarse output. It is the nearest thing in the
system to what Iowan does.

New York is the terminal fallback rather than a named one because its
PostScript name is `.NewYork-Regular` — dot-prefixed, private — and cannot be
requested reliably by name. `.system(design: .serif)` is the supported route
to it.

**And Charter, unlike Iowan, *is* freely redistributable** — Bitstream released
it permissively, and XCharter is the maintained extension. So when Android comes,
Charter is the font to bundle there, and the three platforms end up close rather
than arbitrary.

### Where it applies

**Serif for what is read; sans for what is operated.**

| Iowan Old Style | SF (unchanged) |
|---|---|
| prayers, psalms, readings | sidebar, section titles, tabs |
| the day's liturgical notes | month grid numerals |
| glossary entries | day-list rows, times, "All day" |
| rule titles and notes in prose | buttons, pop-ups, checkboxes |
| reflection questions and answers | Settings, onboarding controls |
| the progress prose | menu bar popover chrome |

The dense month grid and the day list stay SF: figures there need to be tight
and unambiguous, and AppKit controls do not take a custom face cleanly.

*Open:* "all the typeface" in the instruction may mean the whole table above
collapses into Iowan, chrome included. The answer given to the direct question
was reading-serif / chrome-sans, which is what is written here. **To be settled
before the view layer; it does not affect `core`.**

### Implementation

`Theme.reading(_ size:relativeTo:)` in `macos/Sources/Chotki/Theme.swift` is the
only way to ask for the reading face. It resolves `Theme.serifChain` once by
asking `NSFont`, rather than trusting `Font.custom` to have found anything.

**What this uncovered.** The app was already asking for a serif called `Cardo`
in six places — scripture, the fathers, prayers, the glossary term, the welcome,
the thanksgiving line — and **Cardo was never installed and never bundled**.
Every one of them had been rendering in the system sans for months. Nothing
looked broken; it simply was not the font anyone had chosen. `Font.custom` falls
back silently, so a face named at a call site is a claim nobody checks.

Two tests came out of that, both in `macos/Tests/ChotkiTests/TypefaceTests.swift`:

- `TypefaceTests` asserts every face in the chain resolves, and that the family
  names give the real bold and italic cuts rather than synthesised ones.
- `FontCallSiteTests` scans `macos/Sources/Chotki` and fails if any file outside
  `Theme.swift` names a font at the call site again.

Both were checked by breaking them on purpose.

## 5. The closing text

Kept verbatim, at the foot of the section below Saturday:

> If this week showed you something uncomfortable, that is the point. You cannot
> fight what you cannot see. Now you can see it.
>
> Take what you noticed to your priest. Bring it to confession. Pray about it.
> Do not try to fix everything yourself. The point of this week was not to
> become a different person in seven days. The point was to stop pretending you
> do not need to change.

Noted deliberately: this is the one piece of fixed copy in the app that tells
the reader to do something. It is judged compatible with the
descriptive-never-prescriptive rule because it names who to ask — a priest,
confession — which is exactly what `design.md` says the app should do instead of
instructing. It is quoted material, not the app's own voice, and is not
reworded.

## 6. Storage, export and import

Entries live in the **same SQLite database as everything else**, in Application
Support, so they are already in the daily backup, already travel with a move
between machines, and are covered by the WAL rule about copying `-wal` and
`-shm`. Nothing here makes a network call.

Schema version **7**, following `hidden_from_library` at 6.

```sql
CREATE TABLE reflection (
    weekday    INTEGER PRIMARY KEY,   -- 1 = Sunday, matching core's Weekday
    title      TEXT NOT NULL,
    notice     TEXT NOT NULL,
    task       TEXT NOT NULL,
    edited_at  TEXT
);

CREATE TABLE reflection_entry (
    id         TEXT PRIMARY KEY,
    weekday    INTEGER NOT NULL REFERENCES reflection(weekday),
    date       TEXT NOT NULL,
    text       TEXT NOT NULL,
    -- the question as it stood when this was written; see the snapshot rule
    q_title    TEXT NOT NULL,
    q_notice   TEXT NOT NULL,
    q_task     TEXT NOT NULL,
    written_at TEXT NOT NULL,
    UNIQUE(weekday, date)
);
CREATE INDEX reflection_entry_by_date ON reflection_entry(date);
```

`weekday` is the primary key of `reflection` because there is exactly one per
day and there always will be. The migration seeds all seven from the source
text, so they are present on first launch of the new version as well as on a
fresh install.

**Export** writes JSON. **Import merges; it never replaces** — entries are keyed
by weekday and date, duplicates are dropped, everything else is unioned. Import
must never be able to discard what is already there. It accepts both Chotki's
own export and the web artifact's `nepsis:v1` shape, whose `days` object is
keyed 1–7 in the same order, so anything already written on the web comes
across.

`Backup` gains `reflections` and `reflectionEntries`, both optional, so a backup
written before this existed still restores.

### Failure behaviour, carried over

A save that cannot reach the store must **still repaint the interface**. The
entry is already in memory and is valid; swallowing the redraw makes a
successful write look like a dead button. Persist and display are separate
concerns — report the failure and show the entry regardless.

## 7. The library rule

**Daily Reflections** joins the library as **seven templates**, one per weekday
— *Notice the Resistance* every Sunday, *Notice the Quiet* every Monday, and so
on — so the rule list names the day's question directly. Category `.life`,
recurrence weekly on that weekday, no time of day.

Each carries the reflection's own title and its `task` as the summary — taken
from `Reflection.bundled` rather than retyped, so a rewritten question and the
rule that answers it cannot drift apart — and `Reflection.libraryNote` as the
note, which is the header explainer cut down to two paragraphs. As with every
library template, enabling one **copies** it: the copy can be renamed and
retimed freely and keeps no link back.

They can be taken on one at a time from the library, or all seven at once with
**Add this as a daily rule** in the section's header. See §3.1.

Taking these on is deliberate, like every other rule: nothing is enabled by
default. The seven *questions* are seeded on install; the seven *rules* are not.
Those are different things, and conflating them would break a rule that
`design.md` treats as non-negotiable.

## 8. Where the code goes

Per `CLAUDE.md`: **anything that decides belongs in `core`** — which holds even
though only macOS gets an interface, because core plus its tests is the
specification a port is written against.

- `core` — `Reflection`, `ReflectionEntry`, the seven seeded questions, which
  entries a weekday holds, period filtering, the position an entry occupies in
  its weekday's series, the merge rule for import, and the new `Store` methods.
  Tested there.
- `macos` — `ReflectionsView` / `ReflectionsViewContent`, the overlay, and the
  `Theme.serif` helper. The View/ViewContent split is required: the section is a
  `ScrollView`, and `CHOTKI_RENDER` draws no `ScrollView` contents, so without
  it every render of this screen is an empty panel. Verify with
  `CHOTKI_RENDER_WINDOW`, which goes through AppKit.

A new file in `core` is invisible to the `macos` build until
`swift package --package-path macos clean`. This will bite.

## 8.1 The other two platforms — not now, but not forgotten

**Reflections will be ported to iOS and Android.** Nothing is being written for
either yet, deliberately: macOS first, in daily use, before the shape is copied
twice.

What that will cost, so it is not rediscovered later:

- **iOS** inherits `core` unchanged — same Swift, same tests — and rewrites the
  view. It also gets Iowan Old Style free, since the font ships with iOS.
- **Android** is a Kotlin reimplementation. `core`'s new types and their tests
  are the specification it is written against, which is why the decisions go in
  `core` now rather than when the port starts. It needs **Charter bundled**, per
  §4, since Iowan cannot be redistributed.
- **`PortParityTests`** gains a Reflections entry only when both ports have the
  feature. Adding one now would fail CI on two platforms that correctly do not
  have it.
- **`android/PARITY.md` says it is generated from `core/` and should not be
  hand-edited** — but no generator is committed, so bringing it up to date is a
  manual pass today. It needs one, or the port is written against a
  specification that does not mention Reflections.
- The overlay is the part least likely to translate. Arrows either side of a
  modal is a desktop gesture; on a phone it wants to be a swipe, and on Android
  a back-button target. That is an interface decision for those ports, not a
  core one — but every bug found by hand on this project has been in exactly
  that layer.

## 8.2 What the render harness gained

Two panels in this section are raised by the view's own `@State` — the explainer
and the reading overlay — so nothing outside can open them, and a screen that
cannot be drawn is a screen that gets signed off unseen. `ReflectionsView` takes
`initialReading` and `initialExplaining` for that reason, and `MainWindowView`
takes `initialSection`, since the sidebar's selection is `@State` too and
`model.screen` has no case for Reflections.

`RenderMode.inOwnWindow` draws one view in an off-screen window of its own. Three
things it has to do that the shared window did for free, each found by getting it
wrong:

- **Pin the root's frame.** As the root of a window a `ScrollView` has nothing
  above it saying how tall to be, so it reports its content height and the
  hosting view grows to match — which drew the explainer as a strip 12,786
  pixels tall.
- **Paint the ground and set a dark appearance.** `MainWindowView` paints the
  detail column; a view hosted alone drew dark text on white.
- Reusing the main window for this did neither, and quietly.

## 8.3 Something the install turned up

Before installing, a copy of the live record was taken to roll back to if the
migration misbehaved. It showed the database **already at schema 7** — before
the build carrying schema 7 had ever been installed.

The cause: `RenderMode.seededStore()` read the liturgical cache straight out of
the real database, and **`SQLiteStore(path:)` runs `migrate()` on open**. Every
render run this session had been applying the new migration to his live record,
under a comment stating that the original is never opened for writing.

Nothing was lost — 19 rules and 59 occurrences intact, and the migration only
adds two empty tables. But that is luck rather than design: a migration that
rewrote or dropped a column would have done it to his record, silently, during
a screenshot.

Fixed: the harness copies the file — with `-wal` and `-shm`, or it silently
loses whatever is not checkpointed, which here was most of it — and opens the
copy. Verified by comparing the live file's mtime and size across a full render
run: untouched. Written into `CLAUDE.md` too, because the lesson generalises:
**opening a store is a write.**

## 9. Dropped from the artifact

- **Reflect** and **Reflect more deeply** — an AI pass over the entries.
  Removed at Ryan's direction: no API calls and no cost attached to them. The
  guardrail text is preserved in the appendix rather than lost.
- **The artifact's aesthetic** — the raised pane, the side rails of crosses and
  lozenges, the horizontal bands, the IC XC seal, the sampled token table.
  Chotki has `Theme.swift`; ornament reads as kitsch at 12pt. The serif is the
  one thing carried across, and it is carried app-wide.
- **The `nepsis:v1` storage key** as the live format. Superseded by the tables
  above. It survives as an accepted *import* shape only.

## 9.1 The glossary

`GlossaryCoverageTests` now scans the seven as it scans prayers and patristic
passages. Three terms of art in the text the glossary already explained —
*liturgy* (Divine Liturgy), *confession* (Confession), *communion* (Holy
Mysteries).

One it did not: **spiritual father**, in Saturday's reflection. Ryan supplied the
definition on 1 September and it is now written, under the slug
`spiritual-father`, related to *Confession*, *Confessor* and *Prayer rule*. The
committed `android/core/.../glossary.json` was regenerated with it, so the port
has it too.

Worth knowing about the scan: it looks for **capitalised** words mid-sentence,
which in liturgical English is very nearly the definition of a term of art. The
Brotherhood's prose is plain modern English and capitalises nothing, so on this
text the ratchet guards future edits rather than finding much today. All four
terms above were found by reading. Titles are excluded, since "Notice the
Resistance" is title case and every capital in it would read as a term.

## 10. Open items

- **Nobody has typed into it yet.** The render harness proves layout and copy;
  it cannot prove clicking, typing or saving, and this feature is almost
  entirely those. `swift test` covers the model underneath — writing, locking,
  rewriting, import, the failed-write repaint — but the path from a keystroke to
  a stored answer has only been run by tests, never by hand. It needs
  `./install.sh` and a real week.
- **The section is window-only**, and the popover has no route to it at all.
  That is deliberate (§0.1) and asserted by a test, but it means Reflections is
  invisible to anyone who only ever opens the menu bar.
- **`android/PARITY.md` needs regenerating.** It says at the top that it is
  generated from `core/`, but no generator is committed, so it is a manual pass
  and currently does not mention Reflections at all.
- Whether `IowanOldStyle-Titling` suits section headings better than Roman at
  15pt. It is a display cut and is sitting there unused.
- Whether the overlay should size to its content rather than holding 520pt.
  Fixed height stops the pane jumping as you page between a one-line answer and
  a long one, which is why it is fixed — but a short answer leaves a lot of
  empty pane.
- Reminders on a reflection. The seven weekday rules inherit the ordinary rule
  reminders and are `.silent` by default. Nothing reflection-specific is
  planned, and that is worth not answering by accident.

## 11. Appendix — the Reflect guardrails, preserved

Kept verbatim from `nepsis-decisions.md`, which this document replaces. Nothing
in the app uses it. It is here so a carefully-written constraint is not lost
with the file it lived in, should an offline reflection pass ever be
reconsidered.

> The model is **not** a spiritual guide, confessor, elder, or priest, and must
> not act as one. No spiritual direction, no prescribed practices or penances,
> no telling the user what God wants of him or what his sins are, no
> reassurance, no moralising. Its role is strictly observational: recurrences,
> tonal shifts, things named once and dropped, contradictions between days,
> what he circles without naming. Hunches are phrased as questions, not
> conclusions. If the entries are too sparse to see anything, it says so rather
> than inventing a pattern.
>
> Orthodox further reading is permitted **only** where a genuine connection
> exists to what he actually wrote, as one short closing note. If there is no
> real connection, it says nothing at all. Never a generic recommendation.

The fuller `GUARDRAILS` constant it refers to lives only in the web artifact.

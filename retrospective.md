# What went wrong, and what to do differently

Written 22 August 2026, four days and fifty-eight commits after the first line
of this project, and immediately before starting the Android port. It exists so
the port does not repeat the macOS build.

`CLAUDE.md` lists the specific traps in this codebase. This file is about the
*way the work went* — the assumptions underneath the mistakes, and the working
habits that caused or caught them.

---

## The central failure: confusing "it draws" with "it works"

Look at the shape of the history. Phases 1 through 7 — the entire application —
were built and reported complete on **19 August**. Then:

- `Fix: the popover resized itself around whatever tab was showing`
- `Fix: text fields swallowed keystrokes, and glossary back did nothing`
- `Fix: an unclickable checkbox, and a library rule that did nothing`
- `Fix: navigation buttons were dead in the window`
- `Fix: settings were never persisting, so fast rules vanished`
- `The marks were missing from the window, which is the surface that opens`
- `Audit: nine bugs, and progress that stops at yesterday`

Every one of those is the same class of defect: **a thing that was drawn
correctly and did not work.** A checkbox whose tap target was a 1pt stroke.
Text fields in a popover that never became key. Buttons that set a state
nothing read. Settings written to a preferences domain that did not exist.

They were not found by me. They were found by Ryan, using the app.

The cause was a verification tool that could not prove interaction, used as
though it could. `ImageRenderer` produced a PNG; the PNG looked right; the phase
was reported done. The tool's limits were even written down — and then the same
class of bug happened again anyway.

**The rule that follows:** a render proves layout and copy. It cannot prove that
a control is reachable, hit-testable, bound to state that something reads, or
that the screen can be navigated to at all. Never report an interface as
complete on the strength of a picture. Say which of those four things were
actually checked and which were not.

**And the deeper rule:** when a tool's known limitation has caused repeated
misses, fix the tool. Documenting the limitation harder does not work. On 22
August the harness was finally replaced with one that renders through AppKit —
drawing real scroll contents and real controls, printing what a pop-up menu
actually contains, and able to scroll and resize the window between shots. Three
days too late. Every UI bug above was invisible to the old harness and would
have been visible to the new one.

---

## Assumptions that should not have been made

**That one surface is the app.** The popover and the window are separate view
trees. The marks, and then the navigation buttons, worked perfectly in the
popover and were dead in the window — which is the surface that opens by
default. A change is not made until it is made in both.

**That a domain term means what it sounds like.** `.liturgical(.fastDay)` was
used for the Wednesday and Friday fast. It means *any* fast day, so the rule
fell on roughly 180 days a year. The correct expression was
`.weekly([.wednesday, .friday])`. This was a claim about Orthodox practice
encoded in a constructor and never checked against practice.

**That religious detail can be inferred.** The cross was drawn with the
footrest raised on the wrong side. It is wrong in the same way a misspelt name
is wrong, and it stayed wrong until Ryan supplied a reference image. Iconography,
prayer texts, fasting rules and saints' details are not things to reconstruct
from memory. Ask for a source, or say plainly that a priest needs to check it.

**That a stylistic choice of mine is a design decision.** A comment in the
library read "The app's own labels are lowercase by design." That was my
preference, written down as though settled, and Ryan overruled it in one line
four days later. State preferences as preferences and let him decide.

**That tests are inert.** Twice a test suite wrote to Ryan's real machine —
preference files in `~/Library/Preferences`, and an empty backup into
Application Support. Anything a test constructs must be explicitly told not to
touch the world.

**That the installed app is the one just built.** A feature was reported
"missing" that had shipped; Ryan was running a stale binary. Building is not
installing, and installing is not restarting.

**That the target platform will run the language.** The whole project was
designed for portability, the core was carefully kept pure — and only on day
three was it established that **Swift does not run on Android in any practical
way**. That discovery is what makes core a *specification* rather than shared
code. It should have been the first question asked, on day one, because it
changes what "portable" means.

---

## What was retrofitted that should have been designed

The core/platform split — the thing the whole port now depends on — was not
part of the original build. It happened on 21 August, in three commits, and
only because Ryan asked "Is our Core and UI split on this project?"

It worked. It was also two days of decisions living in the wrong layer, and the
audit that moved them found logic in `AppModel` that the port would otherwise
have had to rediscover. **The portability boundary has to exist before the
platform layer is written, not after**, and the test for it should be
mechanical from the first commit — the CI job that fails on an Apple import is
worth more than any amount of good intention.

---

## What worked, and should be kept

- **Mechanical enforcement over intent.** The CI portability guard has never
  once been argued with. Contrast the hand-maintained rule about where logic
  belongs, which drifted for two days.
- **Tests that encode a decision, not a line of code.** The `WindowRoute` test
  asserts every screen routes somewhere; it has since caught two screens added
  without a route. The legacy-database fixture caught two migrations that only
  reversed the newest change.
- **Rendering the real view.** After the ZStack incident — verifying a
  hand-composed `ZStack { Backdrop; Content }` that proved the marks drew and
  said nothing about whether any screen used them — every check has been against
  the actual view in the actual shell.
- **Showing design work before integrating it.** The completion message was
  mocked up and shown before it went in, and Ryan cut it from three variants to
  one. That is a five-minute exchange that saved a wrong feature.
- **Asserting on every scripted edit.** Several early patches silently no-oped
  and looked successful. `assert old in s` is not optional.
- **Ryan's bug reports.** They are accurate, specific, and consistently
  understate the problem. When he says something "appears to do nothing", it
  does nothing, and there is usually a second thing broken next to it.

---

## Working together better

**Say what was not verified.** The most useful sentences in this project have
been the ones admitting a gap: "the picker's menu contents are the one thing I
cannot see." Ryan then checks that specific thing. Silence about a gap costs him
a debugging session.

**When a request has two plausible readings that look very different, show
both.** "The same ochre colour" could have meant the palette's `ochre` — which
is a brick red used for errors — or the gold used everywhere. Rendering the
candidate and looking took two minutes and settled it. Guessing would have
shipped an error-coloured heading; asking would have cost a round trip.

**Ship the check, not the claim.** Every feature since the harness was rebuilt
has come with a screenshot of the actual state — scrolled, resized, or with the
menu dumped. This is the difference between "it should work" and "here it is
working".

**Flag expanded scope explicitly.** The glossary headings were changed when only
the library was asked about, because leaving them mismatched would have looked
like an oversight. That was probably right — but it was said out loud, with an
offer to revert, rather than slipped in.

**A fix goes everywhere the problem is.** Lower-cased headings were reported in
the library. They were fixed there and in the glossary, and settings was flagged
as having the same fault and left alone — a judgement that these were "form
labels rather than content headings", which is exactly the kind of distinction
that matters to nobody looking at the screen. The complaint came back two days
later, with the reasonable observation that this keeps happening.

The report is a sample, not the scope. Search for the pattern, fix all of it,
and if something genuinely should be excluded, do the rest first and then say
what was left out. Flagging an omission is not the same as finishing.

**Do not moralise, do not pad, do not re-litigate.** Corrections get one line.

**Rebase, always.** Ryan edits `README.md` directly on GitHub mid-session. Four
commits in the history are his. Never force over them.

**Watch the real cost.** Fifty-eight commits in four days is fast, but the
first day's speed was borrowed against three days of fixes. A phase reported
complete that is not complete is worse than a phase reported honestly as
half-done.

---

## The one-page version, for the Android port

1. Verify interaction, not appearance. Drive the UI or say you did not.
2. Build the portability guard in CI before the first screen.
3. Do not re-type sacred or liturgical content by hand — move it mechanically.
4. Ask for a reference on anything religious. Do not infer.
5. State assumptions about Orthodox practice as questions for Ryan or a priest.
6. Never let a test touch a real device's storage.
7. Two surfaces means two implementations; a fix to one is not a fix.
8. Say what you could not check, every time.

## A late one, from the Android port

The Reading screen said "No reading stored for this day yet" for a day and a
half of work. Two causes, and both are the old shape wearing new clothes.

`android.permission.INTERNET` was never declared. Every fetch threw
`SecurityException` — into a `runCatching` that dropped it, so the app reported
a calendar it had never once tried to reach in the same words it uses for a
calendar it merely has not reached *today*. The refresh was written to be
forgiving of a network that is down, and forgiveness made a permanent,
structural failure look temporary.

Then, with the permission added, it still said the same thing. The days were
fetched and stored; nothing redrew. `LiturgicalService` keeps its snapshot in an
ordinary map, so Compose has nothing to observe.

Both are the pattern this document already names — something that drew
correctly and did nothing. What is new is that the second one was invisible to
the sixty-two tests then passing, because every one of them set up its state
before composing. Nothing ever arrived *late*. The test added for it
(`CalendarArrivalTest`) was run against the un-fixed code first and watched to
fail; a test for a race that has never been seen to fail is not yet a test.

## Two features that were never ported, and a sentence I wrote about them

The first hour of real-device testing turned up five faults. I told Ryan every
one of them had been invisible on the emulator. That was not true of the two
that mattered, and he was right to say so.

The clock setting and the entire "Remind me" section existed in the macOS app.
Neither was carried to Android. No emulator could have shown that, and neither
could any amount of testing on the phone: **a control that was never written
has nothing to click and nothing to fail.** Missing features are found by
comparing the port against the original, and by nothing else. Both of these
were greppable from the source with no device in the room — `grep -c reminders`
against the Android editor returned 1, and that one hit was a stray line of
copy.

Which is the part worth keeping. The Android editor carried the sentence
"It runs all day, and reminders are spread across the waking hours" — ported
faithfully from the macOS reminders section — sitting above nothing, because
the controls it explains were never written. A line of prose describing a
control that is not there is the loudest signal available that a screen was
ported halfway, and it sat in the file through every review, including the ones
where I grepped that exact file for that exact word.

The consequence was not cosmetic. Phase 11 is testing reminders on a real
device, and reminders could not be configured at all. The phone could not test
the thing the port existed to test.

Calling it an emulator problem made it sound like a hard bug that better tooling
would have caught. It was a missing feature that a checklist would have caught.
The distinction matters because the remedies are opposite: one asks for more
testing, the other for less trust in testing.

**What now guards it:** `PortParityTests` reads both source trees and asserts
that every user-editable part of the shared model is reachable in both
interfaces. It is a source-level check and a crude one, and it fails on exactly
this class of omission, which is the class that has actually happened.

## The iOS port shipped a screen that asked for nothing

Seven faults came back from the first hour on the iPhone 13. Six were ordinary
port gaps of the kind this document already covers. One was a shape I had not
met before, and it is the one worth writing down.

**The reading screen read a cache that nothing filled.** `ReadingView` called
`liturgicalDay(_:)` on the store, found nothing, and displayed the sentence
"The church calendar is the only thing Chotki asks the network for, and it will
fill in when it can reach it." Every word of that was false on iOS. There was
no `LiturgicalService` on the platform, no `OrthocalClient`, no network call of
any kind — `grep -rn "Orthocal\|LiturgicalService" ios/Chotki/` returned
nothing at all. The screen was not slow. It was never going to fill in.

This is not "a control that was never written", which is the failure the
previous entry is about and which `PortParityTests` was built to catch. A
missing control is *absent*: there is nothing to tap, and the gap is visible to
anyone comparing the screens. A reader with no writer is *present and
convincing*. It renders, it explains itself, it tells you it is waiting — and
the explanation it gives is the same one a genuinely slow network would give.
Ryan's report said "It should not take this long for readings to load", which
is exactly the wrong diagnosis and exactly the diagnosis the screen invited.

Android arrived at the same place along a different road: the fetch was written
and the INTERNET permission was not, so every call threw into a `runCatching`
and vanished. Two platforms, two unrelated causes, one symptom — which is a
strong hint the symptom deserves its own guard rather than each cause getting
one.

The second fault worth recording: **iOS had reimplemented `PrayerScreen`.** Core
has that type. It holds the rope rule (a hundred Jesus Prayers are counted, the
Creed is not), the reader's override of that rule, and the count. iOS had a
local three-field struct of the same name in `@State`, so the rope never
followed the prayer, "Show rope" did not exist, and the count was destroyed by
any navigation. Nothing failed, because there was nothing to fail — the local
version was internally consistent. It was just a fork nobody had declared.

Both are now in `PortParityTests`, and both negative controls were run: the
calendar check fails when `LiturgicalService` is removed from the iOS tree, and
the prayer check fails when the "Read" group is taken out of the chooser.

**And a note on the negative controls themselves.** My first attempt at
sabotaging the prayer check replaced `notForRope` with `SABOTAGE_notForRope` —
which still contains `notForRope`, so the test passed and I nearly recorded that
as a verified guard. A negative control that does not actually remove the thing
is worth less than no negative control, because it produces false confidence
rather than none. Then, restoring afterwards, `git checkout --` silently did
nothing for `TermText.swift`, because a new untracked file is not in the index
to restore from; the sabotage sat in the working tree until I grepped for it.
Check the restore, every time, by looking for the sabotage string rather than by
trusting the restore command.

## The guard I wrote one day earlier passed while the bug was live

The iOS fixes shipped with a new `PortParityTests` check: every platform links
the words a newcomer would stop at. It asked whether each platform's source
tree contained `scanOnce` or `.scan(` anywhere in it.

Android contained both — in `RulePrayers.kt`, one screen of three. The Reading
and the Rope drew every word as plain `Text`, so on the two screens where a
newcomer spends most of their time, nothing led anywhere. Ryan found it by
using the app, the day after I wrote the test that was supposed to make that
unnecessary.

This is the same mistake this file already records four times — searching for a
word rather than for the thing — but at a granularity I had not thought about.
The word was not the problem: `scanOnce` is a real call and finding it means
real linking is really happening. The *scope* was the problem. I asked a
question about the platform when the invariant is about the surface. "Does this
app have a glossary" is satisfied by one linked screen. "Does the word I am
looking at lead anywhere" is not satisfied by anything less than all of them.

The rewritten check enumerates files, finds the ones that render prayer
paragraphs or a liturgical commemoration, and requires each of those to link.
It finds its surfaces by what they draw rather than by their names, so moving
the code moves the check with it — the fix for the three earlier times a check
here looked in the wrong file. Run against the unfixed tree it named both
screens, by filename, unprompted.

**The general form, which is worth more than the specific fix:** when writing a
guard, state the invariant as a sentence first and check the quantifier. Mine
should have read "every surface that shows the text links its terms" and I
implemented "some surface does". A test whose quantifier is weaker than the
invariant is not a weak test — it is a test that reports success on a broken
app, which is worse than no test, because it stops anyone looking.

Two smaller things from the same session:

- **Android had no theme.** With no `android:theme` declared the app inherited
  the platform default, which draws an ActionBar carrying `android:label`. So
  there was a system title bar above every screen, doing nothing, that nobody
  had noticed until a second header appeared beneath it. Part of what Ryan
  described as the app feeling "flat and clunky" was a dead bar taking the top
  of every screen.
- **`RopeScreen` kept the count in `remember`.** Identical to the iOS fault
  fixed the day before, found by looking rather than by the parity test — it is
  a state-lifetime bug, not a feature gap, and source-grep parity cannot see it.
  Switching to the Reading and back reset a hundred-knot count to nought. Both
  platforms now hold it beside the screen rather than in it.

## The largest gap yet, and it was in both ports at once

Ryan opened iOS to take a rule on and found there was no way to say when, how
often, or whether to be reminded — the tap saved the template's defaults
straight onto the day. From there it unravelled: no pencil on a rule, no way to
remove one, no way to stand it down for a day, no way to pause it. Then: no
Custom section in the library, and no "Write your own rule" at all.

macOS has carried all of this since its first version, on a right-click menu:
mark as kept, mark as kept late, stand down for this day, edit rule, pause,
resume. **Neither mobile platform had any of it.** Android had a pencil and
nothing else — `standDown` and `remove` sat on `AppState` called from nowhere,
which is a shape this file already describes and I had not thought to check for
again. iOS could not reach its own rule editor at all: `Route.editor` existed,
`RuleEditor.swift` existed and was complete, and no view anywhere navigated to
it. A whole screen, written and unreachable.

`PortParityTests` did not catch a line of it, and the reason is worth stating.
Every check in it was written after a specific bug, and each one asks about the
thing that bug was about — reminders in the editor, the clock in settings, the
calendar fetch, the glossary scan. None asked "does the row offer what the row
offers on the Mac", because nobody had reported that yet. **A test suite grown
entirely from past bugs only ever covers past bugs.** The parity checks now
include the menu's actions and the library's sections, but the general lesson is
that the inventory has to be taken deliberately against the reference
implementation rather than accumulated one incident at a time.

Ryan's instruction is now the rule, in `house-rules.md`: the first platform
built is the specification, later platforms carry all of it, and only the *way
in* may differ. Right-click became long-press. The Mac's fixed footer for the
rope became a toolbar button, because eleven prayers of scroll is not a footer.
Six tabs became five with the glossary reached contextually. Every one of those
is a change of gesture, not of capability — and the moment a difference is a
difference in capability, it is a bug.

**One thing I got right by accident and should do on purpose.** Converting the
row's controls from `NavigationLink` to buttons that push through an
environment action fixed two problems I had not connected: `List` was drawing a
disclosure chevron for every link, and a `NavigationLink` inside a
`.contextMenu` is presented outside the navigation stack, where it does not
reliably work at all. The second would have shipped as "the menu items do
nothing sometimes" — a control that draws correctly and does nothing, which is
the failure this project meets more than any other.

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

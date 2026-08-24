# Chotki for Android

**Status: not started.** This folder holds the groundwork only — the plan, the
specification, and the decisions still to make. No Kotlin, no Gradle, nothing
built. Work begins 23 August 2026.

- **[PORT.md](PORT.md)** — the phases, in order, each with a "done when"
- **[PARITY.md](PARITY.md)** — what `core/` defines and the port must satisfy
- **[../retrospective.md](../retrospective.md)** — how the macOS build went
  wrong, and the guard rails that came out of it

## The one thing to understand first

Swift does not run on Android in any practical way. This is a **reimplementation
in Kotlin**, not shared code — so `core/` and its 280 tests stop being an
implementation and become a *specification*. Everything this app decides is
stated there once. A Kotlin core that passes a translation of those tests is the
same application underneath, and anything left undone shows up as a missing
test rather than as a bug Ryan finds three weeks later.

## Toolchain on this machine, as of 22 August 2026

Checked, not assumed:

| | |
|---|---|
| JDK | **26.0.2 (Temurin)** — the only one installed |
| Android Studio | Not installed |
| Android SDK / `adb` | Not installed |
| Gradle | Not installed |
| Kotlin compiler | Not installed |
| Homebrew | Present, at `/opt/homebrew` |
| Space on the 2TB volume | 1.8 TB free |

**The one real problem: JDK 26 is too new.** The Android Gradle Plugin supports
JDK 17 and 21; it will not build against 26. So a second JDK is needed
regardless of what else is installed — either the one Android Studio bundles
(JetBrains Runtime, currently 21) or a standalone `openjdk@21`.

### What needs installing — revised 24 August, after Studio arrived

Android Studio **2026.1 is installed**. It has not been launched, so the SDK is
not on disk: no platform, no build tools, no `adb`. Those come down during the
first-run wizard.

**One thing left, and it is Ryan's:** open Android Studio and complete the setup
wizard. Accept Google's SDK licences, and let it fetch the SDK platform, the
build tools and the platform tools. Several gigabytes; there is room.

Worth adding while the wizard is open: an **arm64 system image** for the
emulator. The real device is what reminders must finally be proved on — OneUI
decides for itself when to stop background work — but an emulator makes the
short loop much shorter.

Two things from the earlier version of this file are **no longer needed**:

- `brew install openjdk@21`. Studio 2026.1 bundles a JetBrains Runtime at
  **JDK 25**, and pointing command-line builds at the same JDK the IDE uses is
  better than having two. If the Android Gradle Plugin turns out not to accept
  25, install 21 then — but do not install it on spec.
  `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`
- `brew install gradle`. Gradle projects carry their own wrapper; `./gradlew`
  is the right way to build, and it pins the version in the repo rather than
  depending on whatever is on the machine.

### How the work will be verified

There is no Android simulator tool here as there is for iOS, so verification
goes through `adb` from the command line: `adb shell input tap`, `adb exec-out
screencap`, and Compose UI tests through `./gradlew connectedAndroidTest`.

That is enough to *drive* the interface rather than photograph it, which is the
one thing this project has repeatedly got wrong. On-device testing needs USB
debugging enabled on the S21 FE and the authorisation prompt accepted on the
phone itself.

## The stack

Settled by the answers below, except where a row says otherwise.

| | Proposed | Why |
|---|---|---|
| Language | Kotlin | The only sane option; Swift is out |
| Modules | `:core` (pure Kotlin/JVM), `:app` (Android) | Mirrors the Swift split, and the same CI guard applies |
| UI | Jetpack Compose, Material 3 | Declarative, closest to the SwiftUI already written |
| Database | SQLDelight, or raw `androidx.sqlite` | Same schema and migration ladder as macOS. **Not Room**, which wants to own a schema this one already has. No longer needed for file interchange — kept because the schema is part of the specification |
| Dates | No date library | `CalendarDate` is timezone-free integer arithmetic and depends on nothing. Keep it that way |
| HTTP | OkHttp or Ktor, behind `HttpFetching` | Same interface as Swift, so tests stay offline |
| JSON | kotlinx.serialization | Orthocal decoding, and possibly shared content |
| Reminders | `AlarmManager` + `NotificationManager` | Exact alarms need permission from Android 12 |
| Background | `WorkManager` | Daily liturgical fetch, backups |
| Min SDK | **26 (Android 8)** — see the note under question 2 | The floor, not the target. Covers essentially every device in use; the test device runs far newer |
| Target SDK | Latest stable | Required by Play eventually, and it is what the runtime-permission behaviour is written against |
| Tests | JUnit + `kotlin.test`; Compose UI tests | The 280 core tests translate; UI must be *driven*, not screenshotted |
| Repo | This one, as `android/` | One history, one licence, shared content in view |

## Open questions for Phase 0

Answers change the work; guesses would be expensive.

1. **Feature scope for v1** — everything the Mac app does, or a subset to start?
   Launch-at-login has no Android equivalent and drops out either way.

   My answer: everything the Mac app has, please.

2. **Which device**, and which Android version does it run? That sets the real
   minimum, and the emulator profile to test against.

    My answer: The app should run cleanly on the largest number of Android devices currently in use today. I have an S21 FE running Android 13 (Kernel version 4.19.113-29223811) and OneUI 5.1. To my understanding this is fairly old, and should suffice as a minimum requirement sicne most Android devices in use today will have at least this versionor above.

3. **Should the database be interchangeable** with the macOS one — copy the file
   across and it opens? That is nearly free if decided now, and awkward later.
   Note this is *not* sync; syncing between devices is a separate, much larger
   feature.

    My answer: We're not going to worry about sync at all for now. The idea will be that you'll run it on one device, and this device will *the* device the user uses for this app.

4. **Distribution to the Brotherhood** — a direct APK, as with the Mac alpha, or
   the Play Store? Play means a developer account, a review process, and a
   privacy policy; direct means asking people to permit installing from an
   unknown source.

    My answer: Direct APK for now. I will worry about a developer account and the rest later.

5. **Shared content as JSON?** Exporting prayers, glossary, library and readings
   to JSON that both platforms read would make drift impossible — but it changes
   the macOS app too. Worth it if Windows and Linux ports are still planned.

 My answer: As the app may see feature updates and changes that will have to be implemented across platforms, we should account for this in the most efficient way going forward.

6. **Where the priest review stands.** The glossary and prayer texts still need
   it, and duplicating unreviewed content onto a second platform doubles what
   has to be corrected later.


 My answer: I've yet to find a priest running Apple Silicon. Part of why I'm moving forward with the Android SDK now is that this will make it more accessible to more priests -- it'll help me find one to review it.

## What the answers settle — and what they do not

**Settled.** Full feature parity. One device, no sync. Direct APK. Content moves
to a single shared source. The priest review waits on Android reaching a priest.

**Three things need doing before any code**, and all three are Ryan's:

1. **Android Studio and the SDK.** Still not installed. `brew install --cask
   android-studio`, then let its first run fetch the SDK. The licences are
   Google's and have to be accepted by him.
2. **A JDK the Android Gradle Plugin supports.** The only JDK here is 26, which
   it will not build with. Android Studio's bundled runtime covers the IDE;
   `brew install openjdk@21 gradle` covers the command line, which is where the
   work actually happens.
3. **USB debugging on the S21 FE**, if it is to be tested on the real device
   rather than only an emulator. It should be — see the OneUI note below.

### The minimum version needs correcting

The answer to question 2 says Android 13 is "fairly old" and would suffice as a
minimum. It is the reverse: Android 13 is from 2022 and sits on the *new* side
of what is in use. Setting the floor there would exclude a large share of
devices, including most that are more than a few years old — the opposite of
the stated goal.

`minSdk` is a **floor, not a target**. At 26 the app runs on Android 8 and
everything above it, the S21 FE included. So: floor at 26, build against the
latest, and test on Android 13 because that is the device in hand. Android
Studio shows Google's current distribution figures when a project is created;
worth a look then rather than trusting either of our guesses.

### Three risks specific to that device

Named because each one fails *silently*, which is this project's recurring way
of going wrong.

- **`POST_NOTIFICATIONS` is a runtime permission from Android 13.** Not
  requested, notifications simply never appear — no error, no crash. The test
  device is exactly the version where this starts to matter.
- **Exact alarms need permission from Android 12.** A prayer reminder that
  arrives whenever the system feels like it is not a reminder for a rule kept at
  a set hour.
- **OneUI kills background work aggressively.** Samsung's battery optimisation
  is well known for stopping alarms on apps it decides are idle. The app will
  need to ask for an exemption and explain why, and reminders must be verified
  over several real days on the real device, not once on an emulator.

### Two things the answers do not cover

- **His existing history.** "No sync" is settled, but he has had a rule going on
  the Mac since 19 August, and if the phone becomes *the* device that record
  should go with it. A one-time export and import is a fraction of the work of
  sync, and the schema is identical, so it is nearly free — but it has to be
  decided before the Android store is written, not after.
- **What replaces the menu bar.** Full parity means the features, not the
  shapes: Android has no menu bar popover and no login items. The natural
  equivalent is a home-screen widget showing today's rule. Worth knowing whether
  that belongs in v1 or later.

### The shared-content decision needs one more turn

Question 5 asked whether content should move to shared JSON; the answer says to
handle cross-platform updates in the most efficient way. That points at one
source of truth — prayers, glossary, rule library and patristic readings
extracted to JSON, shipped as a resource, decoded by both platforms. It is the
right answer for an app that will keep changing on two platforms, and it is what
stops the prayer texts drifting apart.

It also means **changing the macOS app, which currently works**, and that is not
a change to make on an inference. Confirm before Phase 1.

## Still outstanding on macOS

Not blockers for Android, but they do not disappear:

- Universal binary — needs Xcode, which is still not installed
- Notarisation — needs the $99/year Apple Developer Program, Ryan's call
- Priest review of the glossary, prayer texts and patristic attributions
- Confirming the parish reckoning (Julian is the default)

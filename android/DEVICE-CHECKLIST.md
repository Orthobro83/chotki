# The week on the S21 FE

Phase 11 is the part no emulator can do. Everything below is either something
Samsung's OneUI does differently, or something that only shows up over days.

**You do not need developer mode or USB debugging.** Sideloading an apk needs
neither, and neither is what upsets banking apps. See the Android section of the
README for the five steps.

## The first ten minutes

- [ ] It installs, and Play Protect's warning is the only friction.
- [ ] The icon is the chotki, not a generic robot.
- [ ] It asks for notifications on first launch, and allowing works.
- [ ] Settings › Reminders shows all three as allowed once you have granted
      them, and each line opens the right Android screen.
- [ ] Take up one rule. Tick it. Un-tick it.
- [ ] Settings › Save a copy of your record — it writes a file you can find
      afterwards in Files.

## The things that need days, not minutes

- [ ] **A reminder arrives when the phone has been idle overnight.** This is the
      one that matters most and the one an emulator cannot test — Doze only
      engages on a real device that has been still, unplugged and screen-off for
      a while.
- [ ] **Reminders still arrive on day three or four.** Samsung moves apps you
      have not opened recently into "sleeping apps" on its own, and no app can
      read or change that list from code. Settings › Battery › Background usage
      limits › Never sleeping apps → add Chotki.
- [ ] Reminders survive a reboot.
- [ ] Quiet hours are respected — nothing arrives during them, and what was due
      arrives afterwards rather than being lost.
- [ ] The church calendar keeps filling in as days pass, including a day when
      the phone has had no network.

## The things worth noticing rather than testing

- [ ] Is the day's list in the order you actually pray?
- [ ] Does the progress view read as encouraging on a week you kept badly? That
      is a fixed constraint of this app, and a real bad week is the only honest
      test of it.
- [ ] Does anything in the glossary or the prayers read wrongly to you? All of
      it is still awaiting a priest's review.

## Before the apk goes to anyone else

- [ ] Make the signing key — `android/RELEASE.md`. Once, and backed up.
- [ ] Build a **signed** release and check the certificate is yours, not the
      debug key.
- [ ] Restore a backup onto a second install and confirm the record comes back.
- [ ] Decide what you are telling people it is. The Settings screen says alpha,
      says it is not affiliated with the Brotherhood, and says the texts await a
      priest's review — but a sentence from you when you send it will be read
      more carefully than anything in the app.

## Known, and deliberate

- **Your record does not leave the phone.** Android's own backup is turned off,
  because a record of someone's prayer life is not something to hand to Google.
  The consequence is that uninstalling loses it, and the only way to a new phone
  is Save a copy.
- **A Mac backup will not restore on Android**, and the app says so plainly
  rather than half-reading it. The two encode their stored rules differently;
  that was settled when sync was ruled out.

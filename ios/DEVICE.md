# Chotki on your own iPhone

The Simulator is the daily loop and always will be — it needs no account, no
signing, and nothing expires. This is for what the Simulator cannot tell you:
how it feels in the hand, whether a reminder arrives while the phone is in a
pocket, and whether the type is readable at the size you actually hold it.

## Once, in Xcode

Everything else is scripted; this part is not, because it needs your password
and because Apple mints a certificate the first time and only through a build.

1. Open `ios/Chotki.xcodeproj`.
2. Select the **Chotki** target → **Signing & Capabilities**.
3. Under **Team**, choose your name — it appears as *(Personal Team)*.
   Xcode creates a signing certificate, registers the iPhone, and makes a
   provisioning profile, all in that moment.
4. If it objects that the bundle identifier is unavailable, change
   `PRODUCT_BUNDLE_IDENTIFIER` in `ios/project.yml` to something of your own —
   `info.chotki.app.ryan` will do. A free team cannot use an identifier already
   registered to someone else.

Then tell Claude, and the team id gets written to `ios/team.env` — gitignored,
because a generated project would lose anything set in Xcode's own interface,
and because it is yours.

## On the phone, once

**Developer Mode does not appear until Xcode has seen the device.** That is why
it was not in Settings when you looked: it is revealed by the step above, not
before it.

- **Settings › Privacy & Security › Developer Mode** → on → restart.
- First launch: **Settings › General › VPN & Device Management** → trust.

## Then

```bash
./ios/build-app.sh device
```

Builds, signs, and installs on whichever iPhone is connected.

## What a free account costs you

- **The app stops opening after seven days** and needs rebuilding from here.
  That is the free Personal Team, not a fault. It is why the Simulator stays the
  daily loop.
- Three devices, ten app identifiers.
- **No TestFlight.** Getting this to anyone else — Father Moses, Maximos —
  needs the Developer Program at $99/yr. There is no free path, unlike Android
  where an apk can simply be handed over.

## What only the phone can answer

- [ ] A reminder arrives while the phone is asleep in a pocket, at the hour it
      was set for. iOS delivers local notifications regardless of what the app
      is doing, so this should simply work — but should is not the same as does.
- [ ] The bell and the tick are audible at a sensible volume, and do not stop
      music that is already playing.
- [ ] The text is readable at the size you hold it, and at your Dynamic Type
      setting rather than the default.
- [ ] The prayers scroll comfortably one-handed.
- [ ] The month grid and the day both fit without the rules being pushed off —
      the iPhone 13 is shorter than the 17 Pro this was built against.
- [ ] Nothing celebrates anything.

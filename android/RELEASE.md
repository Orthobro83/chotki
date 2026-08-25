# Making a Chotki apk

## The signing key — once, and never again

Android ties an installed app to the key that signed it. An update signed with
a *different* key will not install over the old one; Android reports it as a
conflicting package and the only remedy is to uninstall — which throws away
that person's record of their rule.

So this key is made once, kept, and backed up. Losing it means every person
running Chotki has to uninstall and start their record again.

**This is yours to make — it needs a password, and the password should not pass
through anyone else's hands, mine included.**

```bash
keytool -genkeypair -v -keystore /Volumes/2TB/claude-vault/projects/chotki/android/chotki-release.jks -alias chotki -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Ryan Macfarlane, O=Chotki"
```

It asks for a keystore password, then whether to use the same one for the key
(yes is fine). Use something you keep in your password manager. `-validity
10000` is about 27 years; a key that expires mid-alpha would be the same
problem as a lost one.

Then write `android/keystore.properties` — gitignored, alongside the key:

```properties
storeFile=chotki-release.jks
storePassword=<what you just typed>
keyAlias=chotki
keyPassword=<what you just typed>
```

Back up **both** the `.jks` and the passwords somewhere that is not this drive.

## Building

```bash
cd /Volumes/2TB/claude-vault/projects/chotki/android && ./gradlew :app:assembleRelease
```

The apk lands at `app/build/outputs/apk/release/app-release.apk`.

If `keystore.properties` is missing the build still succeeds, signed with the
debug key, and says so loudly in the log. That apk is for checking the release
path works — **not** for handing out. The debug key is a well-known shared key
and everyone who has ever run Android Studio has the same one.

## Checking what you are about to send

```bash
cd /Volumes/2TB/claude-vault/projects/chotki/android && ~/Library/Android/sdk/build-tools/36.0.0/apksigner verify --print-certs -v app/build/outputs/apk/release/app-release.apk
```

Look for your own name in the certificate, `Signer #1 certificate DN`, and not
`CN=Android Debug`. Also confirm `debuggable` is false:

```bash
cd /Volumes/2TB/claude-vault/projects/chotki/android && ~/Library/Android/sdk/build-tools/36.0.0/aapt2 dump badging app/build/outputs/apk/release/app-release.apk | grep -E "package|application-debuggable"
```

No `application-debuggable` line at all is the correct result.

## Version numbers

`versionCode` is what Android compares to decide something is an upgrade — it
must go **up** by one on every apk you hand out, or the new one will not install
over the old. `versionName` is what people read, and what the Settings screen
shows so a bug report can be pinned to a build.

Both are in `android/app/build.gradle.kts`, in `defaultConfig`.

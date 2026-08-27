import java.util.Properties

plugins {
    // Kotlin support is built into the Android plugin from AGP 9; applying
    // org.jetbrains.kotlin.android alongside it is now an error.
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "org.chotki.app"
    compileSdk = 37

    defaultConfig {
        applicationId = "org.chotki"
        // The floor, not the target: Android 8 and everything above it, which is
        // essentially every device in use. The test device runs 13.
        minSdk = 26
        targetSdk = 37
        versionCode = 9
        versionName = "0.1.8-alpha"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        // So the app can say which build it is. An alpha handed to a dozen
        // people produces reports like "it did the thing again", and without a
        // version there is no way to know which build they mean.
        buildConfig = true
    }

    /**
     * The release key is Ryan's, and is not in this repository.
     *
     * Android ties an installed app to the key that signed it: an update signed
     * with a different key will not install over it, and the only remedy is for
     * every person who has it to uninstall and lose their record. So the key is
     * made once, kept safe, and never regenerated. `keystore.properties` is
     * gitignored; `android/RELEASE.md` says how to make it.
     */
    val keystore = Properties().apply {
        val file = rootProject.file("keystore.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }
    val signable = keystore.getProperty("storeFile") != null

    signingConfigs {
        if (signable) {
            create("release") {
                storeFile = rootProject.file(keystore.getProperty("storeFile"))
                storePassword = keystore.getProperty("storePassword")
                keyAlias = keystore.getProperty("keyAlias")
                keyPassword = keystore.getProperty("keyPassword")
                // v2 is what installs on everything from Android 7 and is on
                // by default. v3 is the one that permits key rotation later —
                // the only escape hatch there is if this key is ever
                // compromised, since Android otherwise ties the app to it
                // permanently. It costs nothing to carry.
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    /**
     * Emulators the build can create for itself, one per Android behaviour gate.
     *
     * Testing the floor and the ceiling does not cover the middle: the bottom
     * bar drawing under the gesture pill arrived at API 35 and was broken on 35,
     * 36 and 37, while the API 33 device this was developed against showed
     * nothing at all. It was found only because a newer emulator happened to be
     * running.
     *
     * So the levels here are not a sample. Each is where Android changed
     * something this app relies on:
     *
     *   31  exact alarms became a permission; PendingIntent mutability required
     *   33  notifications became a runtime permission
     *   34  exact alarms tightened further
     *   35  edge to edge enforced for apps targeting 35+ — this app targets 37
     *   36  predictive back on by default; orientation lock ignored on large
     *       screens, which is why one of these is a tablet
     *
     * API 37 is absent deliberately: at the time of writing it ships only as
     * beta 16KB-page images, which these sources cannot name. Run that one
     * against a local emulator, as it was.
     *
     * `aosp-atd` images are the small headless ones meant for exactly this.
     * They still download several gigabytes the first time, which is why this
     * is not part of the ordinary build.
     *
     *   ./gradlew :app:gatesGroupDebugAndroidTest     — all of them
     *   ./gradlew :app:api35DebugAndroidTest          — just one
     */
    testOptions {
        managedDevices {
            allDevices {
                create<com.android.build.api.dsl.ManagedVirtualDevice>("api31") {
                    device = "Pixel 6"; apiLevel = 31; systemImageSource = "aosp-atd"
                }
                create<com.android.build.api.dsl.ManagedVirtualDevice>("api33") {
                    device = "Pixel 6"; apiLevel = 33; systemImageSource = "aosp-atd"
                }
                create<com.android.build.api.dsl.ManagedVirtualDevice>("api34") {
                    device = "Pixel 6"; apiLevel = 34; systemImageSource = "aosp-atd"
                }
                create<com.android.build.api.dsl.ManagedVirtualDevice>("api35") {
                    device = "Pixel 6"; apiLevel = 35; systemImageSource = "aosp-atd"
                }
                create<com.android.build.api.dsl.ManagedVirtualDevice>("api36") {
                    device = "Pixel 6"; apiLevel = 36; systemImageSource = "aosp-atd"
                }
                // The one large screen. From API 36 an app targeting 36 or later
                // has its orientation lock ignored here, and this app asks for
                // portrait — so this is the device that says what that does.
                create<com.android.build.api.dsl.ManagedVirtualDevice>("tabletApi36") {
                    device = "Pixel Tablet"; apiLevel = 36; systemImageSource = "aosp-atd"
                }
            }
            groups {
                create("gates") {
                    for (name in listOf(
                        "api31", "api33", "api34", "api35", "api36", "tabletApi36",
                    )) {
                        targetDevices.add(allDevices[name])
                    }
                }
            }
        }
    }

    buildTypes {
        release {
            // R8 is off deliberately. This is an alpha given to people who are
            // doing us a favour by running it, and an obfuscated stack trace
            // from someone who cannot reproduce the crash is worth nothing.
            // The apk is ~8MB either way.
            isMinifyEnabled = false
            isDebuggable = false
            signingConfig = if (signable) {
                signingConfigs.getByName("release")
            } else {
                // Still builds, so the release path is exercised in CI and on a
                // machine without the key — but it is not the apk to hand out.
                logger.warn(
                    "Chotki: no keystore.properties — signing release with the " +
                        "debug key. Do not distribute this apk. See android/RELEASE.md.",
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}


dependencies {
    implementation(project(":core"))
    // NotificationCompat only — the notification API has changed enough between
    // 8 and 13 that hand-rolling it would be a source of bugs on exactly the
    // versions hardest to test.
    implementation("androidx.core:core-ktx:1.17.0")

    val compose = platform("androidx.compose:compose-bom:2025.09.00")
    implementation(compose)
    androidTestImplementation(compose)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.4")

    debugImplementation("androidx.compose.ui:ui-tooling")
    // The interface is driven, not photographed.
    debugImplementation("androidx.compose.ui:ui-test-manifest")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")

    // The interface will be driven, not photographed. Every macOS bug in this
    // project was a control that drew correctly and did nothing.
    // Navigation is decided by a value, so where back goes can be checked
    // without a device — and without finishing an activity mid-suite, which
    // crashes the instrumentation runner for everything after it.
    testImplementation("junit:junit:4.13.2")

    // Espresso, explicitly and current.
    //
    // Compose's ui-test drags in 3.5.0, from 2022, and nothing upgrades it
    // while runner, monitor and core all move — so the suite ran on Android 13
    // and every single test errored on Android 17 with a NoSuchMethodException
    // for android.hardware.input.InputManager.getInstance, a method that
    // version no longer has. The app was fine; the harness was four years old.
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}

plugins {
    // Kotlin support is built into the Android plugin from AGP 9; applying
    // org.jetbrains.kotlin.android alongside it is now an error.
    id("com.android.application")
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
        versionCode = 1
        versionName = "0.1.0-alpha"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}


dependencies {
    implementation(project(":core"))

    // The interface will be driven, not photographed. Every macOS bug in this
    // project was a control that drew correctly and did nothing.
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}

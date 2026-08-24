package org.chotki.app

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

/**
 * A placeholder, replaced in phase 10 by the real interface.
 *
 * It exists so the module builds, installs and runs before anything depends on
 * it — the point of phase 9 is the platform layer underneath, and a screen that
 * proves the app starts is worth more than one that pretends to be finished.
 */
class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(TextView(this).apply { text = "Chotki" })
    }
}

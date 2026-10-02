# Chotki image library review

Open `index.html` in a regular browser. The user’s final decision file approves 323 images and rejects five. The gallery places the five newest approved photographs first; **Approved** and **Rejected** filters remain available for auditing, and **Download decisions** exports the current decision record. The [approval file](approved.json) includes a SHA-256 checksum of the user’s [final decisions](../chotki-image-decisions.json).

The approved images have been added to the Mac app after the original 42, producing a 365-image rotation. The app bundles 75 Commons standard-size copies (up to 1920 pixels wide) and 248 locally reviewed copies (up to 960 pixels wide). `manifest.json` and the app’s `approved-sources.json` retain Commons source pages, creators, image-level rights labels, original dimensions, and focal coordinates. `upgrade_approved.py` can resume the remaining higher-resolution replacements after Wikimedia Commons clears its transfer limit.

Run `swift build-crops.swift` and `python3 build-gallery.py` here to regenerate review crops and gallery data after manifest or focal edits. `install_approved.py` installs the approved local copies into the Mac app’s rotation.

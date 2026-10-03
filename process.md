# Chotki macOS Overhaul Process

Updated: 2026-10-03.

The phase statuses below describe current implementation and verification. Dated implementation-log entries preserve the decisions and evidence at the time; later entries supersede earlier requirements.
Status: 1.0 beta, build 29. Android and the universal Mac build are the public release. iOS is the same version, on the author's phone, and is not a public download. The rope and the cross play only when the process was not running.

## Approach and Progress

Android's current implementation defines the behavior; the supplied desktop screenshot and `elegant.html` define the visual direction, subject to your stated changes.
Decisions made during screenshot review supersede conflicting details in the original phase outline.
I will update each phase below to Pending, In Progress, or Complete, recording the build version, verification results, and remaining issues.
A phase is complete only when its behavior and accessible controls have been checked, alongside its appearance.
Development versions followed `0.x.x-build` until 2026-10-02, when the release name became 1.0 beta. The build number only goes up.

## Phase 1 — Inventory and Baseline

Status: Complete.
- Read Android's screens, navigation, state, core behavior, persistence, and tests feature by feature.
- Record a parity checklist here covering Home, Prayers, Reading, Progress, Library, Glossary, Settings, onboarding, editing, reminders, and backups.
- Identify intentional Mac differences, including the sidebar, menu-bar companion, keyboard/mouse interaction, and launch-at-login.
- Establish baseline core and macOS tests and builds, and inspect existing render and interaction tools.
- Audit Reflections dependencies and stored records before removing the feature.
- Establish one version source and document the first development build identifier.

Completion check: Every Android feature has a mapped Mac destination or an explicit user-approved exclusion, and baseline failures are recorded.

## Phase 2 — Behavior, Settings, and Reflections Removal

Status: Complete.
- Port missing Android decisions into the Swift core, including names, spiritual-father prompt timing, reading order, and completion behavior where needed.
- Preserve backward-compatible settings decoding and existing non-Reflections records.
- Remove Reflections from macOS navigation, library, views, model wiring, and relevant tests/resources.
- Handle existing reflection rules and records explicitly so they cannot leave broken routes or distort progress; do not silently delete historical data.
- Keep shared core changes compatible with iOS and avoid changing the Android reference unintentionally.

Completion check: Relevant behavior and persistence tests pass, old records load safely, and macOS exposes no Reflections feature.

## Phase 3 — Desktop Shell and Navigation

Status: Implemented; hands-on navigation verification pending.
- Build the grouped sidebar: The Day, To Read, The Record, Reference.
- Add a discoverable sidebar-collapse icon and retain navigation when it is collapsed.
- Animate the selection highlight between destinations and give screen changes light fade/slide transitions.
- Apply proper casing to headings throughout the macOS interface.
- Establish spacious padding, serif typography, dark backgrounds, and responsive layouts based on the desktop reference.
- Use scrollbars that appear during scrolling, with horizontal and vertical scrolling where appropriate.
- Honor Reduce Motion and support keyboard navigation and accessible labels.

Completion check: Every destination is reachable with mouse and keyboard at supported window sizes, and collapsing the sidebar causes no clipped content or lost controls.

## Phase 4 — Home, Calendar, and Commitment Cards

Status: Implemented; hands-on card and wheel verification pending.
- Implement the personalized greeting and compact week calendar with arrows and horizontal scrolling.
- Add explicit week/month expansion, preserving selection and expansion state across navigation.
- Match Android's feast, fast, Sunday, selected-day, and old-style-date behavior.
- Build parchment commitment cards with a separate completion circle and an Add control.
- Port card destinations, fasting explanations, and all rule actions: edit, kept/undo, kept late, stand down, pause, and resume.
- Preserve dispensation rules, completion updates, and existing custom rules.

Completion check: Each category opens the correct content; marking never triggers navigation; calendar changes, rule actions, and empty states work correctly.

## Phase 5 — Remaining Screens and Menu-Bar Companion

Status: Implemented; hands-on route verification pending.
- Bring Prayers, the rope, Psalter, Reading, Progress, Library, Glossary, Settings, onboarding, and the rule editor into the new design.
- Preserve glossary links on every reading surface, reminder controls, custom-rule creation, and backup/restore behavior.
- Retain appropriate desktop spacing and complete feature access without copying phone proportions mechanically.
- Redesign the compact menu-bar companion with animated tab selection and access to the full window.
- Check routes in both the full window and popover, including returning from nested content.

Completion check: The parity checklist is satisfied across the full window and companion, with intentional differences documented.

## Phase 6 — Imagery and Subtle Motion

Status: Implemented with the approved 365-image rotation shared across Mac, Android, and iOS; final hands-on motion review remains open.
- Use the approved 365-image library and focal positions stored with the Mac resources. Android generates compressed WebP copies; iOS references the same source folder.
- Show daily sayings with readable overlays and appropriate desktop crops.
- Add slow, subtle pans toward central subjects and faces in image panes except Progress.
- Choose crop/focal positions deliberately; avoid cutting off faces, obscuring text, or restarting motion on routine updates.
- Stop unnecessary animation when panes are hidden and honor Reduce Motion.
- Verify imagery is included in the installed app bundle, not only available during development.

Completion check: All 365 images resolve from the packaged app; sayings remain readable; motion is restrained and Progress imagery stays still.

## Phase 7 — Due-Task Pulses and macOS Notifications

Status: Implemented; Notification Center presentation and pulse review pending.
- Connect due-task events to the relevant navigation section in the window and menu-bar companion.
- Pulse that section in the cards' parchment color for five seconds.
- Deliver a macOS notification through the existing reminder system, respecting notification permission and reminder settings.
- Prevent duplicate alerts and handle simultaneous tasks, completed tasks, sleep/wake, and day rollover.
- Keep pulses from stealing navigation focus; provide a reduced-motion equivalent.

Completion check: Controlled due-task scenarios produce the correct five-second indication and one appropriate notification without changing the current section.

## Phase 8 — End-to-End Verification and Beta Build

Status: In Progress.
- Run relevant Swift core/macOS tests and shared compatibility checks.
- Compare every Android feature against the completed Mac interface, and search for missed old headings, routes, and Reflections surfaces.
- Render the actual window and popover using isolated sample data; never capture the desktop or open the live database for development verification.
- Exercise real interactions with isolated data, including navigation, completion, editing, persistence, reminders, and backups.
- Verify resizing, scrolling, keyboard use, Reduce Motion, image packaging, and the signed app bundle.
- Build and inspect the universal binary; never launch the Intel slice on this Mac.
- Report remaining verification gaps explicitly. The beta name was assigned on 2026-10-02; it does not imply that every manual check below has passed.

Completion check: Feature parity, visual review, interaction checks, data compatibility, and packaging pass; the beta build and validation notes are ready for review.

## Separate Track — Expand the Image Library

Status: Complete at 365 selected images (original 42 plus 323 user-approved additions). The Mac bundle includes all 365 and every new image has a recorded focal point. 75 of 323 approved additions now use higher-resolution Commons copies; upgrading the remaining 248 and final visual interaction review remain open after the beta release.
- Research high-quality public-domain Orthodox imagery conveying beauty and peace, toward a 365-image library.
- Select art and photographs, excluding museum artifacts; prefer real public-domain imagery.
- Use generative AI only if suitable public-domain images cannot meet the 365-image target; generated church visuals must contain no people or generated icons, and may include candles lit in the standard fashion.
- Present candidates with previews, source links, and public-domain evidence.
- Add new imagery only after your approval.
- Track approved additions and the total image count here.

## Separate Track — Life of the Day’s Saint

Status: Implemented with 365 days of the Prologue from Ochrid. This supersedes the Dimitry translation track and its 366-date target. The published source has no February 29 reading; that date remains explicitly unavailable.
- Preserve the published English text, section structure, emphasis, and verse lines.
- Cite each source page and CC BY-SA 4.0 license beneath its reading.
- Select by observed church date, with both calendar dates recorded in the data.
- Keep the Swift and Android JSON collections identical through `core/Tools/ochrid-prologue.py` and content parity tests.
- The saint-life section is collapsible on Mac, Android, and iOS.

## Current Evidence and Open Details

- 1.0 beta, build 29 is the current release, on Android, on the universal Mac build, and on iOS. iOS is not a public download. The earlier reservation of `1.0.0-beta` is lifted. The rope and the cross play on a cold start only. The Windows port is still ahead.
- The fictional-data `Chotki Review.app` uses a distinct bundle identity and in-memory practice store. It does not open the live Chotki record; all physical UI checks here used this review app.
- In the Review window, ordinary clicks were observed to open Morning Prayers, the Jesus Prayer with rope, the day's Gospel, the saint-life Reading section, the Add placard, and “Add a New Rule.” The completion circle changed the selected day's state; the saint-life disclosure collapsed by click. A right-click started the native card menu, and selecting its Expand Card action by keyboard expanded the card.
- 2026-10-03 review: shared core passes 473 tests. The Mac suite runs 81 tests; the sidebar resize render test reports three black-image assertions, while its geometry checks pass. Android and iOS builds were not rerun during that review. Earlier build.11 results remain in the dated log.
- The bundled Prologue contains 365 church-date readings; Swift and Android copies match. February 29 is absent in the published source. Old Calendar lookup uses the observed church date.
- The 365-image Mac rotation is approved and packaged. Of the 323 new images, 75 have higher-resolution Commons copies; 248 still use review-resolution copies. Final Retina sharpness review remains.
- The review app's real Notification Center display, all nested routes at all window sizes, and final image-motion review still require hands-on verification; the beta release does not close these checks.

## 3 October Follow-Up

- iOS now places completion markers after every available scripture band, saint life, departed prayer, and Akathist. Opening a disclosure does not count; the existing UIKit marker requires deliberate scrolling to its end. Missing saint lives have no completion marker.
- The iOS Simulator app builds and the focused scroll-completion test passes. All 474 shared-core tests pass, including a surface guard whose negative control fails when scripture completion is removed. Physical gestures on the installed phone have not been checked in this follow-up.
- Android image packaging now uses pinned Pillow in a project environment, replacing `cwebp` and `sips`. Gradle tracks interpreter and encoder versions; CI installs the same dependency, tests all EXIF orientations, and verifies both APK image libraries. Setup and verification commands are in `android/README.md`.

- Android correction verification: four portable image tests pass, including all eight EXIF orientations, alpha preservation, stale timestamps, cache invalidation, and corrupted output recovery. Both debug and release APKs build and pass verification of all 365 WebP images, dimensions, order, and focal metadata (59.5 MB image payload). Image 08 matches the former upright output in orientation and dimensions, with a visually comparable crop. An unchanged Gradle image task is UP-TO-DATE; a converter edit regenerates the library. Mac source assets are unchanged. Ubuntu CI is configured for the same checks but has not been executed in this local session.

## Implementation Log

- 2026-09-30: macOS baseline passed all 95 tests.
- 2026-09-30: Core baseline ran 452 tests with seven pre-existing issues: Android surface parity (settings, prayer chooser, glossary linking, and Reflections route) plus three shared-content export mismatches.
- 2026-09-30: Development begins at `0.2.0-build.1`; the numeric bundle build is tracked separately for Apple compatibility.
- 2026-09-30: Retired Reflections data remains readable by backups and shared iOS core; the Mac excludes its rules from active practice, reminders, and progress.
- 2026-09-30: The Swift core now includes all eighteen new Android glossary entries, revised welcome copy, and updated Psalter reference; source content was compared semantically with the Android resources.
- 2026-09-30: Core suite passes 456 tests. macOS suite passes 68 tests. Offscreen real-window renders cover Home, month, narrow width, Library, Prayers, Reading, Progress, Settings, glossary, and companion.
- 2026-09-30: The first visual pass found a glossary overlay covering the sidebar and a crowded narrow week strip; both were corrected and verified in a second offscreen render. The collapsed sidebar also renders without clipping.
- 2026-09-30: The 42-image contact sheet shows existing carved artifacts at positions 37 and 38. The existing rotation is retained as requested; candidates to replace artifacts in the eventual 365-image library require approval.
- 2026-09-30: Final shared-core suite passes 456 tests; macOS suite passes 69 tests, including the review-only alert request. The universal release bundle builds, verifies its signature, packages all 42 images, and passes archive integrity checks. It remains `0.2.0-build.1` pending hands-on interaction review; `1.0.0-beta` has not been assigned.
- 2026-09-30: A Launch Services interaction probe did not pass the preview settings reliably and left a review-bundle process running. That exact process was stopped. The live database, WAL, and SHM modification times predate this probe, and no recently modified files appeared in Chotki's application-support directory; no live-store write was observed. Do not use this probe again. The direct in-memory offscreen preview remains the verified method.
- 2026-09-30: Added `Chotki Review.app`, whose own signed bundle key selects the in-memory sample before live services are created. It launched with a distinct bundle identity and no open live-database path. Use this for human interaction review; the offscreen renderer remains the visual baseline.
- 2026-09-30: In response to screenshot review, Home Add controls now route to Library; card and week strips use the ordinary wheel horizontally and hide their bars. The week chevron tracks the selected day, the expanded calendar displays one month at a time with sliding transitions, and scrolling pages fade content at both viewport edges. Progress art preserves its top and shows its quotation and captions. Settings fields align with content and the spiritual-father field has Clear; the rule editor offers the saved name or Someone else with a Suggested by field. The macOS suite passes 69 tests and the updated isolated offscreen renders cover these layouts; live click and wheel behavior still require hands-on review.
- 2026-09-30: Packaged `0.2.0-build.2` as a signed universal app and separately signed fictional-data Review app. Both archive integrity checks pass, bundle version reads `20002`, all 42 rotation images are present, and `git diff --check` is clean. Home, month, and Progress review images were refreshed in `macos/dist/`.
- 2026-09-30: Screenshot follow-up replaced the suggester menu with a field and spiritual-father checkbox. Checking it records the present name on the rule; the first Settings name edit snapshots that name on older marked rules, including archived rules, before any partial typing or clearing. Home completion circles remain separate controls; truncated placards expand and scroll into view, then collapse on the next body click. The week strip is centered, the daily image pan is 15% faster and settles at the image's top edge, and the Progress quote/caption layout is revised. Isolated renders include the expanded card and rule editor.
- 2026-09-30: macOS suite passes 71 tests; shared core passes 456 tests. Android's unchanged reference builds offline. An iOS simulator build found and prompted a fix for the missing rope-rule destination, then passed. A direct Mac UI inspection tool did not return controls in two bounded attempts, so actual clicks, wheel scrolling, and Notification Center display remain for hands-on review.
- 2026-09-30: Started an approval-gated candidate log in `imagery/candidates.md` with three photographer-released CC0 Orthodox photo leads. No image was added to the rotation or app bundle.
- 2026-09-30: Packaged `0.2.0-build.3` as signed arm64/x86_64 release and separately signed fictional-data Review app. Both zip archives pass integrity checks, all 42 rotation images (41 JPEGs and one PNG) are present, the review flag is in the signed bundle, and the final offscreen render completes. `git diff --check` is clean. The Intel slice was not launched and notarization is still separate.
- 2026-09-30: In build.3, a settled-image render confirmed the earlier top-edge endpoint, but image 22's face was partly below the short Home pane. That endpoint was superseded in build.4; no existing image was swapped or edited.
- 2026-09-30: A later review decision replaces that top-edge endpoint: each of the 42 rotation images has a hand-reviewed subject coordinate, and the pan rests with that subject near the upper-middle of the pane. A contact sheet of all 42 final crops prompted corrections to face locations on portrait images; the final isolated render shows image 22 resting on Saint Nicholas's face. No image file was changed or added.
- 2026-09-30: The entire dotted Add placard now has a shaped hit area and opens Library; it shares the Home panel in the main window and companion. macOS tests pass 72/72, including rotation coverage and portrait pan geometry. `0.2.0-build.4` packages as signed arm64/x86_64 release and separately signed fictional-data Review app; both verified offscreen. Live card clicks, scrolling, notifications, and the pan's perceived speed remain for hands-on review before `1.0.0-beta`.
- 2026-09-30: User motion review found some images still and other pans too fast and far. Build.5 halves the pan rate by doubling the duration to about 63 seconds, limits travel to roughly 10–23 points, and starts near each of the 42 hand-reviewed subject coordinates. A versioned daily-pan key allows today's image to replay the corrected motion once, then hold at its subject. Geometry tests cover every image at desktop and companion sizes; perceived motion still needs hands-on review. The signed universal release and isolated Review app build successfully.
- 2026-09-30: Searched and license-checked 23 Commons photographs, visually screened their previews and wide Home-card crops, and recorded twelve proposed images with focal points in `imagery/candidates.md`. Paired source/crop sheets are `macos/dist/candidate-focal-sheet-01.png` and `candidate-focal-sheet-02.png`. The local `imagery/review/index.html` gallery shows each image and crop, lets the user reject/restore candidates, and exports/imports decisions. Its JavaScript syntax and all local assets pass static verification; the in-app browser's file-URL policy prevented automated live interaction testing. These remain candidates only; the rotation is still 42, so 323 approved images remain to reach 365.
- 2026-09-30: Build.5 macOS suite passes 73/73 tests. The ad-hoc signed universal app and isolated Review app package successfully, both ZIP archives pass integrity checks, and the app bundle still contains all 42 rotation images. The isolated settled-image render again centers the selected icon subject. `git diff --check` is clean. The gallery UI has not been live-clicked by automation because the in-app browser declined to open a local file URL.
- 2026-10-01: User confirmed the local interactive reviewer works and asked for at least 323 candidates. The first expanded Commons search yielded 221 rights/size-eligible files. After contact-sheet and wide-crop review, forty were added as review-only previews with individual focal points, bringing the gallery to 52. The app rotation remains 42. A second search yielded 596 more license-eligible leads; visual screening and card-crop review accepted 85 more review-only candidates, bringing the gallery to 137. A targeted follow-up search added 25 more after crop review, bringing the gallery to 162. Named-monastery research added another 38 after crop review, bringing the gallery to 200. A geographically broader search yielded 85 more after screening, bringing the gallery to 285. A final named-cathedral search yielded 38 more after crop review, bringing the gallery to 323 review candidates. The app rotation remains 42 pending user decisions.

- 2026-10-01: The final user decision JSON superseded the first export. It rejects five of 328 candidates and approves every other image, including the five replacements, for 323 additions. The approval record stores the final decision file’s SHA-256. All 323 locally reviewed copies are packaged in Mac rotation positions 43–365 with focal coordinates and Commons provenance. The macOS test suite passes 73/73. Commons allowed an image-level rights recheck of the first 318, then rate-limited the high-resolution download; 75 now use Commons standard-size copies up to 1920 pixels wide, while 248 still use up-to-960-pixel review copies; the latter should be upgraded before beta for Retina sharpness.

- 2026-10-01: Packaged `0.2.0-build.6` as signed arm64/x86_64 release and separate fictional-data Review app. Both ZIPs pass archive integrity; the app bundle contains 365 distinct, readable images and the order/source/focal data. An isolated offscreen Home render displays an approved image at its focal point. The macOS suite passes 73/73. Live click/wheel inspection remains pending because the Computer Use service reported that permissions are not granted; no live personal database was opened.

- 2026-10-01: A paced second high-resolution attempt upgraded 75 approved images to Commons standard-size copies and rechecked all 323 file-level licenses. Commons then returned HTTP 429; the resumable upgrade script now pauses on that response. Build.7 was packaged as signed arm64/x86_64 release and isolated Review app; both ZIPs pass integrity, and the app bundle contains 365 unique readable images. The resource audit accurately records which 75 are upgraded and which 248 remain at review resolution.
- 2026-10-01: User review of the installed app found that card expansion consumed the navigation click, context actions were not available on right-click, and the saint-life title was truncated. Build.8 opens a card's destination on its first click, preserves expansion on a separate control, attaches the Android-equivalent actions directly to the macOS card context menu, routes prayer sequences to the Prayers sidebar, and shrinks long titles to fit. The saint-life title fits in a fictional offscreen render. The macOS suite passes 75/75; the signed universal release and separate fictional-data Review app both package and pass archive integrity checks. A complete public-domain English Orthodox daily saint-life source has not yet been selected, so the saint-life content itself remains open. Direct right-click UI testing remains unavailable because Computer Use did not return an app state.

- 2026-10-01: Build.8's SwiftUI card button and nested context menu still did not receive clicks in either installed app. Build.9 replaces that event layer with a full-card AppKit mouse surface and native `NSMenu`; the face, completion circle, and expand glyph remain SwiftUI visuals. A hosted-window hit test confirms the card surface is the hit target. A full mouse-down/mouse-up pair sent through an ordered, offscreen `NSWindow` opens Morning Prayers, and a right-mouse-down through the same window reaches a menu containing the Android-equivalent actions. An unshown-window click variant failed, which confirmed that direct surface calls alone were too weak a test. The shared core suite passes 456/456; Android core tests and debug assembly pass; the iOS simulator build passes. Physical mouse interaction in the installed app still awaits user verification because Computer Use is unavailable in this session.
- 2026-10-01: Began an English saint-life collection from the public-domain Russian edition of St. Dimitry of Rostov. September 18 (Venerable Eumenios) and October 1 (Apostle Ananias) are included as source-linked, explicitly abridged translations, keyed to the observed church date. Mac, Android, and iOS readers display available lives and clearly say when a day has not yet been translated. This is 2 of 365 dates; translation and review of the rest remain open.
- 2026-10-01: `0.2.0-build.9` is packaged as an ad-hoc signed universal Mac app and a separate signed fictional-data Review app. Both ZIP archives pass integrity checks, both signatures verify, and the final macOS suite passes 76/76. The stronger ordered-window regression reaches both left-click navigation and right-click menu construction. Hands-on interaction in the installed apps is still to be checked by the user.
- 2026-10-01: Physical-coordinate testing in the fictional Review app exposed a SwiftUI scroll-document event boundary that the earlier direct and offscreen tests missed. Build.10 uses a card-local AppKit event monitor: ordinary body clicks open the intended Prayers or Reading destination, the circle toggles completion, and right-click starts the native menu. The menu's Expand Card action was selected by keyboard and enlarged the card. The same physical-click fix now covers the dotted Add placard, “Add a New Rule,” and the saint-life disclosure; all were physically rechecked. The saint-life section is collapsible on Mac, Android, and iOS. September 18 and October 1 now carry complete featured-life translations checked against the linked Russian originals; 363 dates remain. Mac 76/76, core 456/456, Android tests/build, and iOS Simulator build pass.
- 2026-10-01: `0.2.0-build.10` packages as signed arm64/x86_64 release plus a separately signed fictional Review app. Both ZIP archives pass integrity checks. Both `/Applications` copies were updated to build.10 after backing up build.8 and build.9 under `macos/dist/installed-backups/`; the installed Review app physically opened Morning Prayers from a card after installation. The normal app's live record was not opened for testing.
- 2026-10-01: The translation track now also includes the complete September 19 life of the Martyr Zosimas in source, for the next Old Calendar day; it is not yet in build.10. The Russian collection has a February 29 life of John Cassian, so full daily coverage requires 366 dates, separate from the 365-image rotation.
- 2026-10-02: `0.2.0-build.11` includes seven complete featured-life translations in source and both Mac bundles; 359 church dates remain. The shared core passes 456 tests, macOS passes 76 tests, and Android core tests and debug assembly pass. Both signed universal Mac bundles package successfully with arm64 and x86_64 slices; both ZIP archives pass integrity checks, and the release bundle contains all 365 approved daily images. This is a development build, not the beta milestone.
- 2026-10-02: The release name is 1.0 beta, build 29. The opening mark plays when the app is started from a process that was not running, on Android, Mac, and the current iOS build, and not when an already-running app is brought forward. At that point the iOS visual overhaul had not started; the subsequent iOS commit implements it.
- 2026-10-02: iOS takes the shipped name, 1.0 beta, build 29. The phone follows the Android screens. The build number does not move, because no new Android or Mac binary is being handed out, and iOS is not a GitHub release.

## Feature Parity Checklist

| Surface | Required behavior | State |
|---|---|---|
| Home | Greeting, date, fasting guidance, empty state, daily saying | Implemented; final verification pending |
| Calendar | Week/month, selection persistence, arrows, horizontal scroll, calendar marks | Implemented; final verification pending |
| Commitments | Open content, kept/undo, late, stand down, edit, pause/resume, dispensations | Implemented; final verification pending |
| Prayers | Scoped chooser, rope override/count/sound, completion, glossary round trip | Implemented; final verification pending |
| Reading | Held readings first, band navigation, completion after reading, cache/offline | Implemented; final verification pending |
| Psalter | Appointed kathismata, full psalms, manual selection | Implemented; final verification pending |
| Library/editor | Categories, template setup, custom caution, recurring/timed rules, reminders, removal scopes | Implemented; final verification pending |
| Settings/onboarding | Name, priest name, timed prompt, church/clock/observances, notifications, sounds | Implemented; final verification pending |
| Record | Progress prose/figure, stationary artwork, export/merge restore, automatic backup | Implemented; final verification pending |
| Glossary | Search/categories, contextual links and return to the reader | Implemented; final verification pending |
| Mac companion | All destinations, animated highlight, due pulse, full-window access | Implemented; final verification pending |
| Mac platform | Dock preference, login, notifications/actions, wake/day rollover, keyboard | Implemented; final verification pending |

# Showdist

An augmented-reality tape measure for Android, built with Flutter and ARCore.
Point the camera at a surface, tap to drop points, and read off the distances.
Measurements can be saved on the device, browsed in a history, and shared as
a plain-text file through the Android share sheet, or copied as text.

The look is one fixed dark-navy theme, drawn from Sanzo Wada's *A Dictionary
of Color Combinations* — no light/dark switching, no system-theme following:
hairline measuring lines in peachRed, a seaGreen aiming reticle, small dots
for points, and static ruler tick marks along the bottom edge. It is an
independent project and is not affiliated with Google or Android.

## Using it

The app opens straight to a **main menu**: the SHOWDIST wordmark at the top,
then two tools — **Measure** and **Leveler** — as large bordered cards,
Measure the more prominent of the two. Static ruler tick marks run along the
bottom edge. About and Settings are one tap away, top-left and top-right.

The AR session doesn't start until you actually tap Measure — opening the
main menu never touches the camera.

**Measuring.** Like every screen, this one uses the app's one fixed theme.

1. Allow camera access. If the phone lacks Google Play Services for AR, the app
   offers to install it.
2. Move the phone slowly so ARCore can find surfaces. The four dots around
   the screen centre light up when they are on a surface.
3. **Tap** the large button to place a point. Each new point adds a
   segment with its length, and a dashed line shows the live distance from the
   last point to the reticle.
4. **Hold anywhere on screen** once you have two or more points to stop and
   save the measurement — not just the button, so you don't have to aim for
   it. The button's ring fills as you hold, wherever your thumb actually is.
   The screen clears, ready for the next one.

The bottom row, left to right:

| Control | Action |
| --- | --- |
| History | Open the history of saved measurements (count badge) |
| Undo | Remove the last point |
| Button, tap | Place a point at the reticle |
| Hold anywhere on screen (0.8 s) | Save the measurement and start fresh |
| Close | Clear all points without saving |
| M / FT | Metric or imperial display |

Up to 24 points per measurement. Portrait only. The system back gesture/button
returns to the main menu.

**Level.** A bubble level for things mounted on a wall — a shelf, a picture
frame, a TV bracket — using the accelerometer. Hold the phone upright and flat
against the wall (or against whatever you're checking). The dot centres
in the ring and the ring lights up when you're within 0.3° of plumb; the
readout below is the tilt in degrees.

## Settings

Reached from the gear icon on the main menu.

- **Units** — Imperial (default: feet and inches, e.g. `4′ 7 1/2″`) or
  Metric, saved on device and restored on the next launch. The same setting
  drives the in-AR M/FT toggle.

**About**, also reached from the settings screen, shows the app name,
version, a quick-start guide for each tool, a developer section, a licenses
page (Flutter, ARCore, and the bundled JetBrains Mono font), and a contact
email (selectable, to copy). It's also reachable directly from the main
menu's info icon, top-left.

## Saving and exporting

Saved measurements are stored on the device (`recordings.json` in the app's
private storage) and survive restarts. If that file is ever unreadable it is
renamed to `recordings.json.corrupt` rather than overwritten.

### History

The history button opens every saved measurement, newest first. Scroll down to
go further back; each row shows the total, the point count, and a small
sketch of its shape — no date. The back arrow returns to measuring.

- **Tap** a row to see every segment and share or copy it.
- **Long-press** a row, or choose **Select** from the menu, to select several.
  Tap rows to add or remove them, or use **Select all**. The bin deletes the
  selection. Back cancels selection first.
- **Delete all** is in the menu. Every delete asks for confirmation first.

### Sharing and copying

Each measurement has two actions, in the save sheet, the detail sheet, and the
share menu on each history row:

- **Share .txt** writes a plain-text file and hands it to the Android share
  sheet — the standard system picker of whatever's installed (Drive, email,
  chat, notes, anything that accepts a file). The share also carries the same
  text directly, for apps that show only the message and drop the attachment.
- **Copy text** puts that same plain-text summary on the clipboard.

Both produce the same text — the total and every segment, no date or
timestamp:

```
Showdist: 17.00 m
3 points, 2 segments
1. 5.00 m
2. 12.00 m
```

Recordings longer than 20 segments are truncated in the text, with a note
pointing at the attached file for the rest.

Measurements are still ordered newest-first in the app and recorded with an
internal timestamp for storage, but that timestamp isn't shown anywhere or
included in what's shared — only the shared `.txt` file's name carries one
(e.g. `showdist-20260921-164005.txt`), so repeated exports don't overwrite
each other.

## Requirements

- An Android device that supports [ARCore](https://developers.google.com/ar/devices),
  running Android 7.0 (API 24) or newer.
- To build: Flutter (developed on 3.47.5 stable, Dart 3.13.4), JDK 17 or newer,
  and the Android SDK with platform 36.

## Build and run

```sh
flutter pub get
flutter devices                 # find your phone (USB debugging enabled)
flutter run -d <device-id>      # debug build
flutter build apk --release     # release APK
```

The release build is signed with the debug key (see `android/app/build.gradle.kts`),
which is fine for installing on your own devices. Set up a real signing config
before distributing it.

Tests and analysis:

```sh
flutter analyze
flutter test
```

The launcher icon is a set of Android vector drawables, not a Flutter-rendered
asset — see `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
(adaptive: background/foreground/monochrome) and `mipmap-anydpi-v21/ic_launcher.xml`
(a flattened fallback for API 24-25, which predate adaptive icons). Edit the
`drawable/ic_launcher_*.xml` files directly; there's no generation step.

## How it works

ARCore runs natively in Kotlin. Flutter draws every pixel of UI. They talk over
one method channel and one event channel.

```
Kotlin (android/app/src/main/kotlin/com/showconfigs/showdist/)
  ArMeasureController   owns the ARCore Session, permissions and install flow,
                        and the channels ar_measure/ar and ar_measure/frames
  ArMeasureView         GLSurfaceView platform view: draws the camera feed,
                        hit-tests the screen centre each frame, keeps the anchors
  BackgroundRenderer    camera image as a full-screen OpenGL quad

Dart (lib/)
  menu/                 the main menu (Measure / Leveler tool cards, About /
                        Settings icons, the static ruler ticks)
  measure/              AR screen, constellation painter, units, recordings,
                        storage, sharing, the history screen and detail sheet,
                        and the Settings screen
  level/                the accelerometer-driven bubble level
  common/               the tick-ring painter, Caption
  about_screen.dart     app info, per-tool quick start, developer section
```

Each camera frame the native side sends one flat `DoubleArray`. Anchor
positions are projected to screen coordinates natively, so Dart never needs the
camera matrices:

| Index | Meaning |
| --- | --- |
| 0 | Tracking: 0 stopped, 1 tracking, 2 lost |
| 1 | Failure reason: none, bad state, too dark, too fast, few features, camera unavailable |
| 2 | Number of tracked planes |
| 3 | 1 if the screen centre hits a surface |
| 4 to 6 | Reticle hit, world x y z (metres) |
| 7 to 8 | Reticle hit, screen x y (0 to 1, top-left origin) |
| 9 | Number of anchors, then per anchor: world x y z, screen x y, visible |

The layout is documented in `ArMeasureView.kt` and decoded by `ArFrame.parse`.
Hit tests accept a plane (inside its polygon), a depth point, or an oriented
feature point. Depth is enabled automatically on devices that support it, which
improves accuracy on walls and objects.

The camera view is hosted with hybrid composition so the Flutter overlay can
draw above it.

## Testing

`flutter test` runs 55 tests:

- unit formatting (metric and imperial)
- decoding the native frame payload, including truncated payloads
- segment and total maths, the plain-text summary (and its truncation past
  20 segments), and the folder exports are written to
- the recording store: persistence, ordering, removing some or all, change
  notifications, and a corrupt save file
- the history thumbnails (how a 3D measurement is flattened)
- the history screen: newest-first order, the empty state, back, selection,
  select all, delete with confirmation (and cancelling), delete all, system back
  leaving selection first, opening a row, and Copy text reaching the clipboard
- the measuring overlay: a distance label is drawn only when its segment's
  midpoint is on-screen, so no labels are stranded on the edges
- the main menu: both tool cards are present, Leveler opens the bubble
  level, the gear opens Settings

The native ARCore path (session start, hit testing, anchors, projection) and
the Level screen's accelerometer reading have no automated tests, because
both need real hardware. Test them on a device.

## Known limitations

- **Emulator.** The Android emulator's virtual-scene camera did not work in
  testing: ARCore session creation failed on an API 36 x86_64 image, with
  ARCore reporting no default camera 0. Use a physical device.
- Accuracy depends on the device and on the surface. Expect roughly a
  centimetre or two in good conditions; plain, featureless, or shiny surfaces and
  low light are worse.
- Android only, portrait only.

## Dependency notes

- `permission_handler` is pinned to `^12.0.1`. Version 13 and later require
  `compileSdk` 37, which the Gradle and AGP setup here could not resolve.
- `share_plus` is pinned to `^11.0.0`. Version 13 moves to `jni` native-asset
  build hooks, which is a heavier toolchain than a share sheet needs.
- `shared_preferences` stores the Settings screen's units choice.
- `sensors_plus` reads the accelerometer for the Level screen.

## Design

Showdist uses one fixed theme, app-wide — no light/dark switching, no system
theme following. Colours live in `lib/theme.dart` as `Palette`, eight named
constants drawn from Sanzo Wada's *A Dictionary of Color Combinations*:

| Token | Hex | Role |
| --- | --- | --- |
| `darkTyrianBlue` | `#12354E` | Main background — landing, settings, licences |
| `olympicBlue` | `#5A82B3` | Secondary accents — selection/toggle state |
| `lightMauve` | `#9A72AA` | The wordmark and large headings |
| `darkCitrine` | `#8B835B` | Small decorative details — the main menu's ruler ticks |
| `peachRed` | `#F15A30` | Actions — the capture button, placed measurement points |
| `seaGreen` | `#00B49B` | Live/tracking elements — reticle dots, the leveler liquid |
| `warmGray` | `#A1A39A` | The leveler's own background, and muted/secondary text |
| `white` | `#FFFFFF` | Body text, live numbers, the reticle's centre dot |

Every screen is built from these eight colours only. Every text pairing the
app actually uses clears WCAG's 4.5:1 for normal text: white on
`darkTyrianBlue` is 12.8:1, `warmGray` on `darkTyrianBlue` is 5.0:1, and
`darkTyrianBlue` on `warmGray` (the leveler's own readout background) is also
5.0:1. The saturated accents (`olympicBlue`, `lightMauve`, `darkCitrine`,
`peachRed`) sit at 3.2-3.8:1 against `darkTyrianBlue` — enough for icons,
strokes, and large text, which is all they're ever used for; small running
text always stays white or `warmGray`. `seaGreen` is strong enough for small
text too, at 4.9:1.

- **Camera overlay** (`ConstellationPainter`): confirmed points, the lines
  between them, and their labels are peachRed. The reticle's four dots and
  the dashed line reaching for it are seaGreen, distinguishing what's still
  live from what's already placed; the reticle's centre dot and the live
  label (the one that changes as the phone moves) are white. A drop shadow
  under the overlay graphics uses `darkTyrianBlue`, not plain black, so it
  still reads as part of the app's own palette against any real-world
  background.
- **The leveler**: the vial behind the bubble is `warmGray` — the palette's
  "leveler background" — and the bubble itself is seaGreen once plumb
  ("leveler liquid"), white otherwise.
- **Selection state** (History's picked rows, the Settings radio buttons)
  uses `olympicBlue`. Small running text never takes a colour accent — the
  unit toggle's on/off state and the history badge count are told apart by
  weight and opacity, not colour, since none of the accents clear 4.5:1 at
  small sizes.

Text is set in **JetBrains Mono** (bundled under `assets/fonts/`, OFL-1.1
licensed — see `assets/fonts/JetBrainsMono/OFL.txt`), the only font in the
app. Its zero is dotted by default; the app turns on the `zero` OpenType
feature (`FontFeature.slashedZero()`) everywhere so 0/O and 1/l/I stay
unmistakable.

Small filled circles — not diamonds — mark measuring points, the reticle, the
main button, and the level's bubble. The **app icon** is an Android adaptive
icon built from plain vector drawables (`android/app/src/main/res/drawable/
ic_launcher_*.xml`), no lettering: a `darkTyrianBlue` background, and a
foreground of three `seaGreen` dots in a triangle around a white centre dot —
the same reticle motif as the AR overlay. A monochrome layer (the same dots,
single-coloured) supports Android 13+ themed icons.
The **SHOWDIST wordmark** — one word, all caps, `lightMauve` — sits at the
top of the main menu. Below it, **Measure** and **Leveler** are large
bordered cards (`peachRed` and `olympicBlue` respectively), Measure the
larger and more strongly tinted of the two, each filling its share of the
remaining space rather than leaving it empty. Static ruler tick marks —
`darkCitrine`, no animation — run along the very bottom edge, pointing
upward, like a tape measure's edge.

## License

[MIT](LICENSE)

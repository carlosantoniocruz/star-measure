# Showdist

<p align="center"><img src="docs/logo.png" width="160" alt="Showdist logo"></p>

An augmented-reality tape measure for Android, built with Flutter and ARCore.
Point the camera at a surface, tap to drop points, and read off the distances.
Measurements can be saved on the device, browsed in a history, and exported as
CSV or JSON through the Android share sheet, or copied as text.

The look is neon orange on black (or, in light mode, orange throughout):
a flat wordmark, hairline measuring lines, and small diamonds for points and
the reticle. It is an independent project and is not affiliated with Google
or Android.

## Using it

The app opens straight to a **main menu**: **Measurement** (the AR tape
measure) and **Level** (a bubble level), with Settings one tap away, top
right.

**Measuring.**

1. Allow camera access. If the phone lacks Google Play Services for AR, the app
   offers to install it.
2. Move the phone slowly so ARCore can find surfaces. The four diamonds around
   the screen centre turn green when they are on a surface.
3. **Tap** the large diamond button to place a point. Each new point adds a
   segment with its length, and a dashed line shows the live distance from the
   last point to the reticle.
4. **Hold** the button once you have two or more points to stop and save the
   measurement. The screen clears, ready for the next one.

The bottom row, left to right:

| Control | Action |
| --- | --- |
| History | Open the history of saved measurements (count badge) |
| Undo | Remove the last point |
| Diamond button, tap | Place a point at the reticle |
| Diamond button, hold (0.8 s) | Save the measurement and start fresh |
| Close | Clear all points without saving |
| M / FT | Metric or imperial display |

Up to 24 points per measurement. Portrait only. The system back gesture/button
returns to the main menu.

**Level.** A bubble level using the accelerometer: lay the phone flat (screen
up) on a surface. The diamond centres in the ring and the ring lights up when
you're within 0.3° of flat; the readout below is the tilt in degrees.

## Settings

Reached from the gear icon on the main menu. Both choices are saved on device
and restored on the next launch:

- **Theme** — System (default), Light, or Dark. Both themes are neon orange:
  black with neon accents in Dark, an orange base with darker-orange bars and
  cards in Light.
- **Units** — Imperial (default: feet and inches, e.g. `4′ 7 1/2″`) or
  Metric. The same setting drives the in-AR M/FT toggle.

**About**, one tap further in, shows the app name, version, and a licenses
page (Flutter, ARCore, and the bundled JetBrains Mono font).

## Saving and exporting

Saved measurements are stored on the device (`recordings.json` in the app's
private storage) and survive restarts. If that file is ever unreadable it is
renamed to `recordings.json.corrupt` rather than overwritten.

### History

The history button opens every saved measurement, newest first. Scroll down to
go further back; each row shows the total, the point count, the time, and a
small sketch of its shape. The back arrow returns to measuring.

- **Tap** a row to see every segment and share or copy it.
- **Long-press** a row, or choose **Select** from the menu, to select several.
  Tap rows to add or remove them, or use **Select all**. The bin deletes the
  selection. Back cancels selection first.
- **Delete all** is in the menu. Every delete asks for confirmation first.

### Sharing and copying

Each measurement has three actions, in the save sheet, the detail sheet, and the
share menu on each history row:

- **Share CSV** and **Share JSON** write a file and hand it to the Android share
  sheet, so it can go to Drive, email, chat, or any other app that accepts files.
  The share also carries the total and every segment length as plain text, for
  apps that ignore attachments.
- **Copy text** puts that plain-text summary on the clipboard:

  ```
  Showdist: 17.00 m
  3 points, 2 segments · Sep 21, 16:40
  1. 5.00 m
  2. 12.00 m
  ```

**CSV** has one row per segment and a final total row:

```
recorded_at,segment,from_point,to_point,length_m,length_display,x1_m,y1_m,z1_m,x2_m,y2_m,z2_m
```

`length_display` is formatted in whichever unit system is selected when you
share. `length_m` is always metres.

**JSON** carries the same data as structured fields:

```json
{
  "app": "Showdist",
  "recorded_at": "2026-09-21T16:40:05.000",
  "unit_system": "metric",
  "total_m": 17.0,
  "total_display": "17.00 m",
  "coordinates": "ARCore world space, metres; origin is where the AR session started",
  "points":   [{ "index": 1, "x": 0.0, "y": 0.0, "z": 0.0 }],
  "segments": [{ "index": 1, "from": 1, "to": 2, "length_m": 5.0, "length_display": "5.00 m" }]
}
```

Coordinates are in ARCore's world space. They describe the shape and the
distances accurately relative to each other, but the origin is wherever the AR
session started, so they are not a position in the room or on a map.

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

The launcher icon (adaptive, with a themed monochrome layer, plus legacy icons
and `docs/logo.png`) is rendered from the same painter as the About screen's
badge. After changing `lib/common/wordmark_painter.dart`, regenerate it with:

```sh
flutter test tool/generate_icons.dart
```

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
  menu/                 the main menu (Measurement / Level / Settings)
  measure/              AR screen, constellation painter, units, recordings,
                        storage, sharing, the history screen and detail sheet,
                        and the Settings screen
  level/                the accelerometer-driven bubble level
  common/               the diamond shape, the wordmark painter, Caption
tool/generate_icons.dart  renders the launcher icon from the in-app wordmark
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

`flutter test` runs 60 tests:

- unit formatting (metric and imperial)
- decoding the native frame payload, including truncated payloads
- segment and total maths, CSV and JSON export, CSV escaping, the plain-text
  summary, and the folder exports are written to
- the recording store: persistence, ordering, removing some or all, change
  notifications, and a corrupt save file
- the history thumbnails (how a 3D measurement is flattened)
- the history screen: newest-first order, the empty state, back, selection,
  select all, delete with confirmation (and cancelling), delete all, system back
  leaving selection first, opening a row, and Copy text reaching the clipboard
- the measuring overlay: a distance label is drawn only when its segment's
  midpoint is on-screen, so no labels are stranded on the edges
- the main menu: both tiles are present, Level opens the bubble level, the
  gear opens Settings

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
- `shared_preferences` stores the Settings screen's theme and units choices.
- `sensors_plus` reads the accelerometer for the Level screen.

## Design

Colours live in `lib/theme.dart` as `Palette`, a `ThemeExtension` reached with
`Palette.of(context)`, plus the raw hues in `Hue`:

| | Neon `#FF5F1F` | Bright `#FF7A33` | Burnt `#B8430F` | Deep `#7A2A06` | Ink `#111111` | Black `#000000` |
| --- | --- | --- | --- | --- | --- | --- |

- **Dark** (default under System, on an OLED-friendly black): background and
  bars are Black, text is white, the active/accent colour is Neon.
- **Light**: a light grey base (`#EDEDED`), not orange — a full orange field
  read as too loud. Bars are a slightly darker grey, cards are white, text is
  a soft dark grey (`#262626`, not harsh pure black), and the accent is
  Burnt — a deeper, muted orange — since Neon has too little contrast against
  any light background to use as text or an icon colour.
- **Camera overlay** (`ConstellationPainter`): lines, the four reticle
  diamonds, and distance labels are always Neon with a small dark drop
  shadow, regardless of theme — it sits on the live camera feed, not the
  app's own chrome. The reticle's centre dot is white, so it stays visible
  against the diamonds around it.

Every text/background combination the app actually uses was checked against
WCAG's 4.5:1: in Dark, white and Neon on Black (21:1, 6.9:1); in Light,
`#262626` on the darkest light-mode surface (11:1) and Burnt on the
background (4.7:1). Secondary/"muted" text is a second solid colour, not the
primary colour at reduced opacity, so dimming it can't quietly drop it below
the ratio a screen was checked at.

Text is set in **JetBrains Mono** (bundled under `assets/fonts/`, OFL-1.1
licensed — see `assets/fonts/JetBrainsMono/OFL.txt`), the only font in the
app. Its zero is dotted by default; the app turns on the `zero` OpenType
feature (`FontFeature.slashedZero()`) everywhere so 0/O and 1/l/I stay
unmistakable.

The diamond shape (`lib/common/diamond.dart`) marks measuring points, the
reticle, the main button, and the level's bubble. The app icon and the About
screen's badge (`lib/common/wordmark_painter.dart`) are a flat wordmark —
"SHOW" in white over "DIST" in black, on Neon — sized to fit whichever icon
layer it's rendered into (adaptive foreground, legacy, monochrome, or the
full-bleed `docs/logo.png`). The main menu draws the same two words without
the orange backdrop, coloured from the theme instead (`onBase` / `emphasis`)
so it reads directly against the page, over a slow drift of ruler tick marks
along the top and bottom edges.

## License

[MIT](LICENSE)

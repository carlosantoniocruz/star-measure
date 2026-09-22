// Regenerates the launcher icon from the in-app tick-ring painter.
//
//   flutter test tool/generate_icons.dart
//
// (It runs under `flutter test` only because that provides the dart:ui engine
// needed to rasterise; it isn't part of the app's test suite.)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:showdist/common/tick_ring_painter.dart';
import 'package:showdist/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

/// px per density for a 1dp = 1px @ mdpi base.
const _density = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

Future<void> _write(String path, int px, void Function(Canvas, Size) draw) async {
  final recorder = ui.PictureRecorder();
  final size = Size(px.toDouble(), px.toDouble());
  draw(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes.buffer.asUint8List());
}

void main() {
  test('generate launcher icons', () async {
    for (final entry in _density.entries) {
      final d = entry.value;
      final dir = '$_res/mipmap-${entry.key}';

      // Legacy icon (Android 7 and earlier): rounded square, black
      // background baked in, ring filling most of it.
      final legacy = (48 * d).round();
      await _write('$dir/ic_launcher.png', legacy, (c, s) {
        c.save();
        c.clipRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.width * 0.22)));
        const TickRingPainter().paint(c, s);
        c.restore();
      });

      // Adaptive layers are 108dp; the visible circle is the centre 66dp
      // (0.305 of the canvas as a radius), and the background colour comes
      // from ic_launcher_background.xml, so only the ring goes here.
      final adaptive = (108 * d).round();
      await _write(
        '$dir/ic_launcher_foreground.png',
        adaptive,
        (c, s) =>
            const TickRingPainter(outerFraction: 0.29, ringWidthFraction: 0.11, paintBackground: false).paint(c, s),
      );

      // Themed (monochrome) layer: the same ring as a flat silhouette.
      await _write('$dir/ic_launcher_monochrome.png', adaptive, (c, s) {
        c.saveLayer(
          Offset.zero & s,
          Paint()..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        );
        const TickRingPainter(outerFraction: 0.29, ringWidthFraction: 0.11, paintBackground: false).paint(c, s);
        c.restore();
      });
    }

    // Full-bleed square for the README and store listings.
    await _write('docs/logo.png', 512, (c, s) => const TickRingPainter().paint(c, s));

    File('$_res/mipmap-anydpi-v26/ic_launcher.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
''');

    File('$_res/values/ic_launcher_background.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">${_hex(Hue.black)}</color>
</resources>
''');
  });
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

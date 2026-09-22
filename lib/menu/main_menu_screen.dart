import 'package:flutter/material.dart';

import '../about_screen.dart';
import '../level/level_screen.dart';
import '../measure/measure_screen.dart';
import '../measure/settings_screen.dart';
import '../settings.dart';
import '../theme.dart';

/// The app's home screen: the SHOWDIST wordmark, then Measure and Leveler.
/// About and Settings are one tap away, top corners; static ruler ticks run
/// along the bottom edge.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key, required this.settings});

  final AppSettings settings;

  static const _tickBandHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.darkTyrianBlue,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _tickBandHeight,
              child: CustomPaint(painter: _RulerPainter()),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: 'About',
                icon: const Icon(Icons.info_outline_rounded, color: Palette.warmGray),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined, color: Palette.warmGray),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => SettingsScreen(settings: settings)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, _tickBandHeight),
              child: Column(
                children: [
                  const SizedBox(height: 52),
                  const Text(
                    'SHOWDIST',
                    style: TextStyle(
                      fontFamily: showdistFontFamily,
                      fontWeight: FontWeight.w800,
                      fontSize: 34,
                      letterSpacing: 3,
                      color: Palette.lightMauve,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // The two tools fill the remaining space themselves — big,
                  // centred touch targets rather than an empty gap around
                  // small ones — with Measure given the larger share.
                  Expanded(
                    flex: 3,
                    child: _ToolCard(
                      label: 'MEASURE',
                      description: 'Point the camera, tap two spots, get the distance.',
                      prominent: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => MeasureScreen(settings: settings)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    flex: 2,
                    child: _ToolCard(
                      label: 'LEVELER',
                      description: 'Hold flat against a wall to check plumb.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const LevelScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static ruler ticks along the bottom edge, pointing upward — a baseline
/// hugging the very bottom, with alternating minor/major ticks rising from
/// it, like a tape measure's edge. Fixed, no animation.
class _RulerPainter extends CustomPainter {
  const _RulerPainter();

  static const _minorSpacing = 24.0;
  static const _majorEvery = 5;
  static const _minorHeight = 14.0;
  static const _majorHeight = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    // darkCitrine — "small decorative details" — full-strength, not faded,
    // with stroke width (not opacity) carrying the minor/major and baseline
    // hierarchy.
    final minor = Paint()
      ..color = Palette.darkCitrine
      ..strokeWidth = 1.6;
    final major = Paint()
      ..color = Palette.darkCitrine
      ..strokeWidth = 2.4;
    final baseline = Paint()
      ..color = Palette.darkCitrine
      ..strokeWidth = 1.6;

    final y = size.height - 1;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), baseline);

    var i = 0;
    for (var x = 0.0; x < size.width + _minorSpacing; x += _minorSpacing, i++) {
      final isMajor = i % _majorEvery == 0;
      final h = isMajor ? _majorHeight : _minorHeight;
      canvas.drawLine(Offset(x, y), Offset(x, y - h), isMajor ? major : minor);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => false;
}

/// A tool's entry on the main menu: a bordered, tappable block with a label
/// and a one-line description. [prominent] (Measure) draws a stronger
/// peachRed border and tint and bigger type; the quieter option (Leveler)
/// uses olympicBlue at lower weight.
class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.label,
    required this.description,
    required this.onTap,
    this.prominent = false,
  });

  final String label;
  final String description;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final accent = prominent ? Palette.peachRed : Palette.olympicBlue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: prominent ? 32 : 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: prominent ? 0.9 : 0.45)),
            color: prominent ? accent.withValues(alpha: 0.10) : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: showdistFontFamily,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        fontSize: prominent ? 24 : 17,
                        color: Palette.white,
                      ),
                    ),
                    SizedBox(height: prominent ? 10 : 5),
                    Text(
                      description,
                      style: TextStyle(color: Palette.warmGray, fontSize: prominent ? 14 : 12.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward_rounded, color: accent, size: prominent ? 26 : 20),
            ],
          ),
        ),
      ),
    );
  }
}

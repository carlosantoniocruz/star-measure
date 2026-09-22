import 'package:flutter/material.dart';

import '../level/level_screen.dart';
import '../measure/history_screen.dart';
import '../measure/measure_screen.dart';
import '../measure/recording_store.dart';
import '../measure/settings_screen.dart';
import '../settings.dart';
import '../theme.dart';

/// The app's home screen: the SHOWDIST wordmark, then Measure — with its
/// History sub-menu just beneath — and Leveler. Settings (and About, inside
/// it) is one tap away, top right; static ruler ticks run along the bottom edge.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key, required this.settings, required this.store});

  final AppSettings settings;

  /// Saved measurements, shared with Measure and History.
  final RecordingStore store;

  static const _tickBandHeight = 84.0;

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
                  // Compact cards, centred in the space left between the
                  // wordmark and the ruler, rather than stretched to fill it.
                  const Spacer(),
                  _ToolCard(
                    label: 'MEASURE',
                    description: 'Point the camera, tap two spots, get the distance.',
                    prominent: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MeasureScreen(settings: settings, store: store),
                      ),
                    ),
                  ),
                  _HistoryLink(
                    store: store,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HistoryScreen(store: store, units: settings.units),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ToolCard(
                    label: 'LEVELER',
                    description: 'Hold flat against a wall to check plumb.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const LevelScreen()),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Measure's sub-menu: saved measurements, with a live count. Indented and
/// hung off a peachRed rule so it reads as part of Measure, not a third tool.
/// History itself is where rows are picked and bulk-shared or copied.
class _HistoryLink extends StatelessWidget {
  const _HistoryLink({required this.store, required this.onTap});

  final RecordingStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: [
          Container(width: 1.5, height: 44, color: Palette.peachRed.withValues(alpha: 0.6)),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                  child: ListenableBuilder(
                    listenable: store,
                    builder: (context, _) {
                      final n = store.items.length;
                      return Row(
                        children: [
                          const Icon(Icons.history_rounded, color: Palette.warmGray, size: 18),
                          const SizedBox(width: 10),
                          const Text(
                            'HISTORY',
                            style: TextStyle(
                              fontFamily: showdistFontFamily,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              fontSize: 13,
                              color: Palette.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              n == 1 ? '1 saved' : '$n saved',
                              style: const TextStyle(color: Palette.warmGray, fontSize: 12),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Palette.warmGray, size: 20),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Static ruler ticks along the bottom edge, pointing upward — a baseline
/// lifted a little off the very bottom, with alternating minor/major ticks
/// rising from it, like a tape measure's edge. Fixed, no animation.
class _RulerPainter extends CustomPainter {
  const _RulerPainter();

  static const _minorSpacing = 24.0;
  static const _majorEvery = 5;
  static const _minorHeight = 24.0;
  static const _majorHeight = 52.0;

  /// Gap between the baseline and the bottom of the band.
  static const _lift = 16.0;

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

    final y = size.height - _lift;
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
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: prominent ? 18 : 14),
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
                        fontSize: prominent ? 20 : 16,
                        color: Palette.white,
                      ),
                    ),
                    SizedBox(height: prominent ? 6 : 4),
                    Text(
                      description,
                      style: TextStyle(color: Palette.warmGray, fontSize: prominent ? 13 : 12, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward_rounded, color: accent, size: prominent ? 22 : 18),
            ],
          ),
        ),
      ),
    );
  }
}

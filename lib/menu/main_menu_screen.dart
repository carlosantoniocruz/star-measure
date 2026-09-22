import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../common/caption.dart';
import '../level/level_screen.dart';
import '../measure/measure_screen.dart';
import '../measure/settings_screen.dart';
import '../settings.dart';
import '../theme.dart';

/// The app's home screen: choose Measurement or Level. Settings is one tap
/// away, top-right.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with SingleTickerProviderStateMixin {
  /// Drift of the ruler ticks, in pixels.
  final _offset = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((d) => _offset.value = d.inMicroseconds / 1e6 * _speed);

  static const _speed = 26.0; // px/s

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: _offset,
                builder: (context, offset, _) => CustomPaint(painter: _RulerPainter(offset: offset, palette: palette)),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Settings',
                icon: Icon(Icons.settings_outlined, color: palette.onBaseMuted),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => SettingsScreen(settings: widget.settings)),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      _MenuTile(
                        icon: Icons.straighten_rounded,
                        label: 'MEASUREMENT',
                        palette: palette,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => MeasureScreen(settings: widget.settings)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MenuTile(
                        icon: Icons.architecture_rounded,
                        label: 'LEVEL',
                        palette: palette,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const LevelScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A drifting ruler edge — a baseline with alternating minor/major tick
/// marks hanging from it, like a tape measure — behind the menu's tiles.
/// Replaces the wordmark as the screen's main visual: bigger, and always
/// moving sideways.
class _RulerPainter extends CustomPainter {
  const _RulerPainter({required this.offset, required this.palette});

  final double offset;
  final Palette palette;

  static const _minorSpacing = 24.0;
  static const _majorEvery = 5;
  static const _minorHeight = 16.0;
  static const _majorHeight = 34.0;
  static const _bandY = 0.30; // fraction of the screen height

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = palette.emphasis.withValues(alpha: 0.16)
      ..strokeWidth = 1.6;
    final major = Paint()
      ..color = palette.emphasis.withValues(alpha: 0.32)
      ..strokeWidth = 2.4;
    final baseline = Paint()
      ..color = palette.emphasis.withValues(alpha: 0.22)
      ..strokeWidth = 1.6;

    final y = size.height * _bandY;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), baseline);

    final period = _minorSpacing * _majorEvery;
    final shift = offset % period;
    var i = 0;
    for (var x = -shift; x < size.width + _minorSpacing; x += _minorSpacing, i++) {
      final isMajor = i % _majorEvery == 0;
      final h = isMajor ? _majorHeight : _minorHeight;
      canvas.drawLine(Offset(x, y), Offset(x, y + h), isMajor ? major : minor);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.offset != offset || old.palette != palette;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap, required this.palette});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: palette.onSurface, size: 26),
              const SizedBox(width: 18),
              Expanded(child: Caption(label, size: 15, spacing: 2, color: palette.onSurface)),
              Icon(Icons.chevron_right_rounded, color: palette.onSurfaceMuted),
            ],
          ),
        ),
      ),
    );
  }
}

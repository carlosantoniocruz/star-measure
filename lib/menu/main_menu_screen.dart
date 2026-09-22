import 'package:flutter/material.dart';

import '../common/caption.dart';
import '../common/wordmark_painter.dart';
import '../level/level_screen.dart';
import '../measure/measure_screen.dart';
import '../measure/settings_screen.dart';
import '../settings.dart';
import '../theme.dart';

/// The app's home screen: choose Measurement or Level. Settings is one tap
/// away, top-right.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Settings',
                icon: Icon(Icons.settings_outlined, color: palette.onBaseMuted),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => SettingsScreen(settings: settings)),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: const CustomPaint(painter: WordmarkPainter()),
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      _MenuTile(
                        icon: Icons.straighten_rounded,
                        label: 'MEASUREMENT',
                        palette: palette,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => MeasureScreen(settings: settings)),
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
